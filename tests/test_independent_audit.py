"""Adversarial Prompt 2 checks using an oracle independent of production feasibility code."""

import itertools
import json
import numpy as np
import pandas as pd
import pytest
from sklearn.linear_model import LogisticRegression
from sklearn.isotonic import IsotonicRegression
from backend.optimizer import GroupOptimizer, SCALE
from backend.service import metrics
from backend.verify import validate_submission
from scripts.audit_independent import (
    enumerate_group,
    submission_check,
    probability,
    ROOT,
)


def fixture(engine):
    return engine.grid[
        (engine.grid.scenario_id == 3)
        & (engine.grid.store_id == 2)
        & (engine.grid.day_date == "2026-02-13")
        & (engine.grid.shift_code == "OPEN")
    ].copy()


def test_independent_submission_oracle_and_decimal_traces(engine):
    result = submission_check(engine.submission("AUDIT"))
    assert result["valid"]
    trace = pd.DataFrame(result["trace"]).sort_values(
        ["scenario_id", "store_id", "dept_id", "day_date", "shift_code"]
    )
    actual = engine.allocations.sort_values(
        ["scenario_id", "store_id", "dept_id", "day_date", "shift_code"]
    )
    for c in ["regular", "flex", "overtime", "cost"]:
        np.testing.assert_allclose(trace[c], actual[c], atol=1e-9)


@pytest.mark.parametrize(
    "case", ["one_worker", "both_request", "zero", "closed_pharmacy", "worst_disrupt"]
)
def test_adversarial_pools_against_exhaustive_oracle(engine, case):
    g = fixture(engine)
    if case in ["one_worker", "both_request"]:
        g["available_regular_employees"] = [2, 3, 2]
        g["max_overtime_employees"] = 0
        g["cross_trained_flex_employees"] = [1, 1, 0]
        g["min_staff"] = 1
        g["demand"] = [5, 5, 1] if case == "both_request" else [5, 1, 1]
    if case == "zero":
        for col in [
            "available_regular_employees",
            "max_overtime_employees",
            "cross_trained_flex_employees",
        ]:
            g[col] = 0
    if case == "closed_pharmacy":
        g.loc[
            g.dept_id == 95,
            [
                "is_open",
                "paid_hours",
                "available_regular_employees",
                "max_overtime_employees",
                "cross_trained_flex_employees",
                "min_staff",
                "demand",
            ],
        ] = 0
    n, cost, ps, shortfall = enumerate_group(g, engine.service)
    opt = GroupOptimizer(g, engine.service)
    for tol in [0, 0.02, 0.06]:
        p = opt.solve(tol)
        chosen = tuple(a["employees"] for a in p["allocations"])
        ix = np.flatnonzero((n == chosen).all(axis=1))
        assert len(ix) == 1
        score = np.rint(ps * SCALE).sum(axis=1)
        eligible = score >= score.max() - round(tol * g.is_open.sum() * SCALE)
        assert abs(cost[ix[0]] - cost[eligible].min()) < 1e-7
        assert p["minimum_staffing_shortfall"] == shortfall
        if case == "closed_pharmacy":
            assert p["allocations"][2]["employees"] == 0
        if case == "zero":
            assert all(a["probability"] == 0 for a in p["allocations"])


def test_calibration_partition_including_exact_boundaries():
    y = np.array([0, 1, 0, 1, 1, 0])
    p = np.array([0.0, 0.2, 0.4, 0.6, 0.8, 1.0])
    m = metrics(y, p)
    assert sum(b["n"] for b in m["calibration"]) == len(y)
    assert m["brier"] == pytest.approx(np.mean((y - p) ** 2))


def test_service_metrics_independent_refit(engine):
    source = pd.read_csv(ROOT / "v_ShiftHistory.csv")
    std = (
        pd.read_csv(ROOT / "comp_LaborStandard.csv")
        .set_index("dept_id")
        .labor_hours_per_workload_unit
    )
    source = source[source.is_open.eq(1)].copy()
    source["u"] = (
        source.shift_demand_units * source.dept_id.map(std) / source.worked_labor_hours
    )
    for dept, d in source.groupby("dept_id"):
        m = engine.service.metrics[int(dept)]
        train = d[d.day_date < "2026-01-29"]
        test = d[d.day_date >= "2026-01-29"]
        if m["model"] == "logistic":
            fit = LogisticRegression(C=m["regularization_C"], max_iter=1000).fit(
                train[["u"]], train.met_target
            )
            z = fit.intercept_[0] + fit.coef_[0, 0] * test.u.to_numpy()
            p = 1 / (1 + np.exp(-z))
        else:
            p = (
                IsotonicRegression(
                    increasing=False, out_of_bounds="clip", y_min=0.005, y_max=0.995
                )
                .fit(train.u, train.met_target)
                .predict(test.u)
            )
        p = np.clip(p, 0.005, 0.995)
        y = test.met_target.to_numpy()
        assert m["test"]["brier"] == pytest.approx(np.mean((p - y) ** 2))
        ranks = pd.Series(p).rank().to_numpy()
        pos = y == 1
        n1 = pos.sum()
        n0 = len(y) - n1
        auc = (ranks[pos].sum() - n1 * (n1 + 1) / 2) / (n1 * n0)
        assert m["test"]["auc"] == pytest.approx(auc)
        # Direct probability reconstruction also agrees with final inference.
        np.testing.assert_allclose(
            probability(engine.service, dept, 30, np.arange(1, 60), 4),
            engine.service.probability(dept, 30, np.arange(1, 60), 4),
        )


def test_weekday_forecasts_recomputed_without_forecast_module(engine):
    raw = pd.read_csv(ROOT / "comp_FactShiftDemand.csv")
    daily = raw.groupby(["store_id", "dept_id", "day_date"]).demand_units.sum()
    for r in engine.forecast.backtest.itertuples():
        if not r.method.startswith("same_weekday"):
            continue
        local = daily.loc[(r.store_id, r.dept_id)]
        local = local[(local.index < r.origin) & (local > 0)]
        past = local[
            pd.to_datetime(local.index).dayofweek == pd.Timestamp(r.day_date).dayofweek
        ].tail(int(r.method[-1]))
        assert r.prediction == pytest.approx(past.mean())
    for (store, dept, day), rows in engine.grid[engine.grid.scenario_id == 1].groupby(
        ["store_id", "dept_id", "day_date"]
    ):
        past = daily.loc[(store, dept)]
        past = past[(past.index < day) & (past > 0)]
        expected = (
            past[pd.to_datetime(past.index).dayofweek == pd.Timestamp(day).dayofweek]
            .tail(4)
            .mean()
        )
        assert rows.demand.sum() == pytest.approx(expected)


def test_invalid_metadata_and_hostile_counts_fail_closed(engine):
    t = engine.submission("AUDIT")
    for col in [
        "scenario_id",
        "scenario_code",
        "is_open",
        "min_staff",
        "draft_scheduled_employees",
    ]:
        bad = t.copy()
        bad[col] = bad[col].astype(object)
        bad.loc[0, col] = "CORRUPT"
        assert not validate_submission(bad)["valid"]
    for badvalue in [float("inf"), 1e30, "not-a-number"]:
        bad = t.copy()
        bad["submitted_employees"] = bad.submitted_employees.astype(object)
        bad.loc[0, "submitted_employees"] = badvalue
        assert not validate_submission(bad)["valid"]


def test_frontier_and_last_worker_against_complete_domain(engine):
    g = fixture(engine)
    opt = GroupOptimizer(g, engine.service)
    n, cost, ps, _ = enumerate_group(g, engine.service)
    totalp = ps.sum(axis=1)
    for p in opt.frontier():
        j = np.flatnonzero(
            (n == [a["employees"] for a in p["allocations"]]).all(axis=1)
        )[0]
        assert not ((cost < cost[j] - 1e-6) & (totalp >= totalp[j] - 1e-10)).any()
    base = opt.solve(0.02)
    workers = np.array([a["employees"] for a in base["allocations"]])
    baseline = sum(a["probability"] or 0 for a in base["allocations"])
    result = opt.last_worker(base)
    for a in result["alternatives"]:
        counts = np.array([r["employees"] for r in a["allocations"]])
        j = np.flatnonzero((n == counts).all(axis=1))[0]
        assert a["incremental_cost"] == pytest.approx(cost[j] - base["cost"])
        assert a["net_expected_targets_gain"] == pytest.approx(totalp[j] - baseline)
    if result["recommendation"]:
        assert (
            result["recommendation"]["net_expected_targets_gain"]
            >= max(a["net_expected_targets_gain"] for a in result["alternatives"])
            - 1 / SCALE
        )


def test_future_actual_features_cannot_change_ridge_predictions(engine):
    from backend.forecast import predict

    d = engine.forecast.daily
    tr = d[d.day_date < "2026-02-05"]
    hold = d[d.day_date >= "2026-02-05"].copy()
    p = predict(tr, hold, "ridge")
    hold["daily_demand_units"] = 1e12
    hold["worked_employees"] = 999999
    hold["met_target"] = 0
    np.testing.assert_array_equal(p, predict(tr, hold, "ridge"))


def test_ridge_predictions_independent_matrix_construction(engine):
    from sklearn.linear_model import Ridge

    d = engine.forecast.daily
    for origin in ["2026-01-29", "2026-02-05"]:
        for (store, dept), local in d.groupby(["store_id", "dept_id"]):
            tr = local[local.day_date < origin]
            te = local[
                (local.day_date >= origin)
                & (
                    local.day_date
                    < (pd.Timestamp(origin) + pd.Timedelta(days=7)).strftime("%Y-%m-%d")
                )
            ]
            cols = ["is_holiday", "has_promotion", "temperature"]
            mean = tr[cols].mean()
            sd = tr[cols].std(ddof=0).replace(0, 1)

            def matrix(frame):
                return np.column_stack(
                    [np.eye(7)[frame.weekday], ((frame[cols] - mean) / sd).to_numpy()]
                )

            fit = Ridge(alpha=10, solver="lsqr").fit(
                matrix(tr), np.log(tr.daily_demand_units)
            )
            expected = np.exp(fit.predict(matrix(te)))
            b = engine.forecast.backtest
            actual = b[
                (b.origin == origin)
                & (b.method == "ridge")
                & (b.store_id == store)
                & (b.dept_id == dept)
            ].prediction
            np.testing.assert_allclose(actual, expected, rtol=1e-5)
