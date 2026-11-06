import numpy as np
import pandas as pd
from backend.data import read, audit
from backend.forecast import predict


def test_complete_source_audit():
    report = audit()
    assert report["passed"]
    assert all(x["passed"] for x in report["checks"])


def test_forecast_past_only_weekly_origins(engine):
    b = engine.forecast.backtest
    assert (b.training_max < b.origin).all()
    assert (b.day_date >= b.origin).all()
    assert b.groupby("method").size().eq(126).all()
    assert set(b.method) == {
        "same_weekday_2",
        "same_weekday_3",
        "same_weekday_4",
        "ridge",
        "calendar_3",
    }


def test_forecast_reproducible_and_no_future_access(engine):
    f = engine.forecast
    origin = "2026-02-05"
    tr = f.daily[f.daily.day_date < origin]
    va = f.daily[f.daily.day_date >= origin]
    p = predict(tr, va, f.selected)
    again = predict(tr, va, f.selected)
    np.testing.assert_array_equal(p, again)
    recorded = f.backtest[
        (f.backtest.origin == origin) & (f.backtest.method == f.selected)
    ]
    np.testing.assert_allclose(p, recorded.prediction)
    # Independent same-weekday arithmetic fixture.
    if f.selected.startswith("same_weekday"):
        row = va.iloc[0]
        n = int(f.selected[-1])
        past = (
            tr[
                (tr.store_id == row.store_id)
                & (tr.dept_id == row.dept_id)
                & (tr.weekday == row.weekday)
            ]
            .sort_values("day_date")
            .tail(n)
        )
        assert p[0] == past.daily_demand_units.sum() / len(past)


def test_forecast_macro_wape_avoids_cross_department_unit_pooling(engine):
    f = engine.forecast
    expected = f.evaluation.groupby("method").wape.mean().to_dict()
    assert f.scores == expected
    assert f.selected == min(expected, key=expected.get)


def test_daily_shift_reconciliation_and_exact_scenarios(engine):
    f = engine.grid
    base = f[f.scenario_id == 1]
    np.testing.assert_allclose(
        base.groupby(["store_id", "dept_id", "day_date"]).demand.sum(),
        base.groupby(["store_id", "dept_id", "day_date"]).daily_forecast.first(),
        rtol=1e-12,
    )
    np.testing.assert_allclose(f.demand, f.base_demand * f.demand_multiplier)
    np.testing.assert_allclose(
        f.groupby(["scenario_id", "store_id", "dept_id", "day_date"]).demand.sum(),
        f.groupby(
            ["scenario_id", "store_id", "dept_id", "day_date"]
        ).scenario_daily_forecast.first(),
    )
    b = f[f.scenario_id == 1].sort_values(
        ["store_id", "dept_id", "day_date", "shift_code"]
    )
    d = f[f.scenario_id == 3].sort_values(
        ["store_id", "dept_id", "day_date", "shift_code"]
    )
    np.testing.assert_array_equal(b.demand, d.demand)
    assert (
        f.loc[f.is_open == 0, ["demand", "demand_low", "demand_high"]].eq(0).all().all()
    )
    assert ((f.demand_low <= f.demand) & (f.demand <= f.demand_high)).all()


def test_service_validation_and_monotone_bounds(engine):
    for dept, metric in engine.service.metrics.items():
        assert metric["test"]["n"] > 100
        assert metric["test"]["brier"] < metric["baseline_test_brier"]
        assert metric["test"]["auc"] > 0.8
        ps = engine.service.probability(dept, 30, np.arange(1, 101), 4)
        assert np.all(np.diff(ps) >= -1e-10)
        assert ((ps >= 0.005) & (ps <= 0.995)).all()
