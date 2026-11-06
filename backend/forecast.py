"""Weekly-origin backtests, shrinkage calendar analogues and reconciled forecasts."""

import numpy as np
import pandas as pd
from sklearn.compose import ColumnTransformer
from sklearn.preprocessing import OneHotEncoder, StandardScaler
from sklearn.pipeline import make_pipeline
from sklearn.linear_model import Ridge
from .data import read, OUT, write_json

METHODS = ["same_weekday_2", "same_weekday_3", "same_weekday_4", "calendar_3", "ridge"]
FEATURES = ["weekday", "is_holiday", "has_promotion", "temperature"]


def daily_history():
    d = (
        read("v_ShiftHistory")
        .groupby(["store_id", "dept_id", "day_date"], as_index=False)
        .first()
    )
    d["weekday"] = pd.to_datetime(d.day_date).dt.dayofweek
    return d[d.is_costco_closed == 0].copy()


def calendar_role(role):
    if "Pre_" in role:
        return "pre"
    if role in ("MLK_Holiday", "Presidents_Day_Holiday"):
        return "holiday"
    # New Year rebound is not a defensible Presidents Day rebound analogue.
    return "normal"


def calendar_factor(train, row):
    role = calendar_role(row.holiday_window_role)
    if role == "normal":
        return 1.0, 0
    d = train[train.dept_id == row.dept_id].copy()
    d["role"] = d.holiday_window_role.map(calendar_role)
    normal = (
        d[d.role == "normal"].groupby(["store_id", "weekday"]).daily_demand_units.mean()
    )
    ratios = []
    dates = []
    for r in d[d.role == role].itertuples():
        base = normal.get((r.store_id, r.weekday), np.nan)
        if base > 0:
            ratios.append(r.daily_demand_units / base)
            dates.append(r.day_date)
    n = len(set(dates))
    if not n:
        return 1.0, 0
    # Three prior independent calendar dates equal the prior weight; stores are not independent holidays.
    return float(np.clip(1 + (np.mean(ratios) - 1) * n / (n + 3), 0.85, 1.2)), n


def predict(train, rows, method):
    result = []
    for r in rows.itertuples():
        local = train[(train.store_id == r.store_id) & (train.dept_id == r.dept_id)]
        if method == "ridge":
            enc = ColumnTransformer(
                [
                    ("weekday", OneHotEncoder(handle_unknown="ignore"), ["weekday"]),
                    ("numeric", StandardScaler(), FEATURES[1:]),
                ]
            )
            model = make_pipeline(enc, Ridge(alpha=10, solver="lsqr"))
            model.fit(local[FEATURES], np.log(local.daily_demand_units))
            value = float(
                np.exp(model.predict(pd.DataFrame([r._asdict()])[FEATURES])[0])
            )
        else:
            n = 3 if method == "calendar_3" else int(method[-1])
            same = local[local.weekday == r.weekday].sort_values("day_date").tail(n)
            if len(same) < 2:
                raise ValueError("Insufficient same-weekday training support")
            value = float(same.daily_demand_units.mean())
            if method == "calendar_3":
                value *= calendar_factor(train, r)[0]
        result.append(max(0.0, value))
    return np.array(result)


class Forecast:
    def __init__(self):
        self.daily = daily_history()
        logs = []
        # Both folds predict a full seven-day horizon; no same-week holdout updates.
        for origin in ["2026-01-29", "2026-02-05"]:
            tr = self.daily[self.daily.day_date < origin]
            va = self.daily[
                (self.daily.day_date >= origin)
                & (
                    self.daily.day_date
                    < (pd.Timestamp(origin) + pd.Timedelta(days=7)).strftime("%Y-%m-%d")
                )
            ]
            for m in METHODS:
                preds = predict(tr, va, m)
                for (_, r), p in zip(va.iterrows(), preds):
                    logs.append(
                        dict(
                            origin=origin,
                            training_max=tr.day_date.max(),
                            day_date=r.day_date,
                            store_id=int(r.store_id),
                            dept_id=int(r.dept_id),
                            method=m,
                            actual=float(r.daily_demand_units),
                            prediction=p,
                        )
                    )
        self.backtest = pd.DataFrame(logs)
        self.backtest["absolute_error"] = abs(
            self.backtest.actual - self.backtest.prediction
        )
        ev = []
        for (m, s, d), v in self.backtest.groupby(["method", "store_id", "dept_id"]):
            ev.append(
                dict(
                    method=m,
                    store_id=s,
                    dept_id=d,
                    n=len(v),
                    mae=v.absolute_error.mean(),
                    wape=v.absolute_error.sum() / v.actual.sum(),
                )
            )
        self.evaluation = pd.DataFrame(ev)
        # Equal-weight group WAPE avoids pooling incompatible department workload units.
        self.scores = self.evaluation.groupby("method").wape.mean().to_dict()
        self.selected = min(self.scores, key=self.scores.get)
        # Benchmark is available for future only. Reconstructed 4-week method is its honest backtest surrogate.
        self.metrics = {
            "selected": self.selected,
            "wape": self.scores,
            "aggregation": "Macro average of nine warehouse/department WAPEs; no pooling of incompatible units.",
            "holdout_rows_per_method": 126,
            "origins": ["2026-01-29", "2026-02-05"],
            "benchmark_note": "Provided planning-week benchmark has no future actual labels. same_weekday_4 is its reconstructed rolling comparator.",
            "ridge_support": "27-34 daily training rows per warehouse/department; strongly regularized, no future actual features.",
        }
        self.evaluation.to_csv(OUT / "forecast_evaluation.csv", index=False)
        self.backtest.to_csv(OUT / "forecast_backtests.csv", index=False)
        self.planning = self.build()

    def build(self):
        g = read("v_PlanningWeekGrid")
        base = g[g.scenario_id == 1].copy()
        rows = base.groupby(["store_id", "dept_id", "day_date"], as_index=False).first()
        rows["weekday"] = pd.to_datetime(rows.day_date).dt.dayofweek
        # If calendar model is not selected, retain explicit neutral adjustment and show analogue only as a stress range.
        rows["daily_forecast"] = predict(self.daily, rows, self.selected)
        rows["calendar_factor_applied"] = [
            calendar_factor(self.daily, r)[0] if self.selected == "calendar_3" else 1.0
            for r in rows.itertuples()
        ]
        rows["calendar_analogue_factor"] = [
            calendar_factor(self.daily, r)[0] for r in rows.itertuples()
        ]
        rows["calendar_support_days"] = [
            calendar_factor(self.daily, r)[1] for r in rows.itertuples()
        ]
        h = read("v_ShiftHistory")
        records = []
        for r in rows.itertuples():
            past = h[
                (h.store_id == r.store_id)
                & (h.dept_id == r.dept_id)
                & (h.day_type == r.day_type)
                & (h.is_open == 1)
            ]
            shares = past.groupby("shift_code").shift_share_of_day.mean()
            shares = shares / shares.sum()
            e = self.backtest[
                (self.backtest.method == self.selected)
                & (self.backtest.dept_id == r.dept_id)
            ]
            residual = float(np.quantile(e.absolute_error / e.actual, 0.9))
            # Stress envelope, not a statistical confidence interval: rare future holiday adds ten points.
            stress = residual + (0.1 if r.holiday_window_role != "Normal" else 0.0)
            for block in base[
                (base.store_id == r.store_id)
                & (base.dept_id == r.dept_id)
                & (base.day_date == r.day_date)
            ].itertuples():
                share = float(shares.get(block.shift_code, 0)) if block.is_open else 0.0
                records.append(
                    dict(
                        store_id=r.store_id,
                        dept_id=r.dept_id,
                        day_date=r.day_date,
                        shift_code=block.shift_code,
                        daily_forecast=r.daily_forecast,
                        shift_share=share,
                        base_demand=r.daily_forecast * share,
                        relative_stress=stress,
                        calendar_factor_applied=r.calendar_factor_applied,
                        calendar_analogue_factor=r.calendar_analogue_factor,
                        calendar_support_days=r.calendar_support_days,
                    )
                )
        out = g.merge(
            pd.DataFrame(records),
            on=["store_id", "dept_id", "day_date", "shift_code"],
            validate="many_to_one",
        )
        out["demand"] = out.base_demand * out.demand_multiplier
        out["scenario_daily_forecast"] = out.groupby(
            ["scenario_id", "store_id", "dept_id", "day_date"]
        ).demand.transform("sum")
        out["demand_low"] = out.demand * (1 - out.relative_stress).clip(lower=0)
        out["demand_high"] = out.demand * (1 + out.relative_stress)
        out["forecast_method"] = self.selected
        out.to_csv(OUT / "forecast_planning_week.csv", index=False)
        b = read("PlanningWeek_BenchmarkForecast")
        self.benchmark = rows[
            ["store_id", "dept_id", "day_date", "daily_forecast"]
        ].merge(b, on=["store_id", "dept_id", "day_date"])
        self.benchmark.to_csv(OUT / "forecast_vs_benchmark.csv", index=False)
        return out
