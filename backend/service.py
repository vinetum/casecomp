"""Interpretable monotone department models with separated selection/test periods."""

import numpy as np
import pandas as pd
from sklearn.linear_model import LogisticRegression
from sklearn.isotonic import IsotonicRegression
from sklearn.metrics import brier_score_loss, roc_auc_score
from .data import read, OUT


def metrics(y, p):
    bins = []
    for i, lo in enumerate(np.linspace(0, 1, 6)[:-1]):
        bins_index = np.minimum((np.asarray(p) * 5).astype(int), 4)
        mask = bins_index == i
        if mask.any():
            bins.append(
                dict(
                    lower=float(lo),
                    n=int(mask.sum()),
                    predicted=float(p[mask].mean()),
                    observed=float(y[mask].mean()),
                )
            )
    return dict(
        n=len(y),
        brier=float(brier_score_loss(y, p)),
        auc=float(roc_auc_score(y, p)) if len(np.unique(y)) > 1 else None,
        observed_attainment=float(np.mean(y)),
        calibration=bins,
        ece=sum(b["n"] * abs(b["predicted"] - b["observed"]) for b in bins) / len(y),
    )


class Service:
    def __init__(self, diagnostics=True):
        h = read("v_ShiftHistory")
        self.standards = (
            read("comp_LaborStandard")
            .set_index("dept_id")
            .labor_hours_per_workload_unit.to_dict()
        )
        h = h[(h.is_open == 1) & (h.worked_labor_hours > 0)].copy()
        h["utilization"] = (
            h.shift_demand_units * h.dept_id.map(self.standards) / h.worked_labor_hours
        )
        self.models = {}
        self.metrics = {}
        self.history = h
        for dept, d in h.groupby("dept_id"):
            tr = d[d.day_date < "2026-01-22"]
            va = d[(d.day_date >= "2026-01-22") & (d.day_date < "2026-01-29")]
            te = d[d.day_date >= "2026-01-29"]
            candidates = []
            for c in [1.0, 10.0, 100.0, 1000.0]:
                model = LogisticRegression(C=c, max_iter=1000).fit(
                    tr[["utilization"]], tr.met_target
                )
                if model.coef_[0, 0] < 0:
                    p = np.clip(
                        model.predict_proba(va[["utilization"]])[:, 1], 0.005, 0.995
                    )
                    candidates.append(
                        (brier_score_loss(va.met_target, p), "logistic", c)
                    )
            iso = IsotonicRegression(
                increasing=False, out_of_bounds="clip", y_min=0.005, y_max=0.995
            ).fit(tr.utilization, tr.met_target)
            candidates.append(
                (
                    brier_score_loss(va.met_target, iso.predict(va.utilization)),
                    "isotonic",
                    None,
                )
            )
            score, kind, c = min(candidates, key=lambda x: x[0])

            def fit(data):
                if kind == "logistic":
                    return LogisticRegression(C=c, max_iter=1000).fit(
                        data[["utilization"]], data.met_target
                    )
                return IsotonicRegression(
                    increasing=False, out_of_bounds="clip", y_min=0.005, y_max=0.995
                ).fit(data.utilization, data.met_target)

            fitted = fit(pd.concat([tr, va]))

            def proba(m, u):
                return np.clip(
                    (
                        m.predict_proba(pd.DataFrame({"utilization": u}))[:, 1]
                        if kind == "logistic"
                        else m.predict(u)
                    ),
                    0.005,
                    0.995,
                )

            p = proba(fitted, te.utilization.to_numpy())
            final = fit(d)
            self.models[int(dept)] = (kind, final)
            self.metrics[int(dept)] = {
                "model": kind,
                "regularization_C": c,
                "selection_brier": float(score),
                "test": metrics(te.met_target.to_numpy(), p),
                "train_rows": len(tr),
                "selection_rows": len(va),
                "final_fit_rows": len(d),
                "historical_attainment": float(d.met_target.mean()),
                "baseline_test_brier": float(
                    brier_score_loss(
                        te.met_target,
                        np.full(len(te), pd.concat([tr, va]).met_target.mean()),
                    )
                ),
                "coefficient": float(final.coef_[0, 0]) if kind == "logistic" else None,
                "note": "Selection ends Jan 28; held-out Jan 29–Feb 11. Final model refit through Feb 11. No warehouse effects; limited support.",
            }
        if diagnostics:
            self.chart()

    def probability(self, dept, demand, n, hours):
        n = np.asarray(n, dtype=float)
        u = np.divide(
            float(demand) * self.standards[int(dept)],
            n * hours,
            out=np.full(n.shape, 10.0),
            where=(n * hours) > 0,
        )
        kind, model = self.models[int(dept)]
        flat = np.atleast_1d(u).ravel()
        p = (
            model.predict_proba(pd.DataFrame({"utilization": flat}))[:, 1]
            if kind == "logistic"
            else model.predict(flat)
        )
        bounded = np.clip(p, 0.005, 0.995).reshape(n.shape)
        return np.where(n * hours > 0, bounded, 0.0)

    def chart(self):
        import matplotlib

        matplotlib.use("Agg")
        import matplotlib.pyplot as plt

        fig, axes = plt.subplots(1, 3, figsize=(13, 3.8))
        for ax, (dept, m) in zip(axes, self.metrics.items()):
            bins = m["test"]["calibration"]
            ax.plot([0, 1], [0, 1], color="#aaa", ls="--")
            ax.plot(
                [b["predicted"] for b in bins],
                [b["observed"] for b in bins],
                "o-",
                color="#097e73",
            )
            ax.set(
                title=f"Department {dept} • held-out calibration",
                xlabel="Predicted attainment",
                ylabel="Observed attainment",
                xlim=(0, 1),
                ylim=(0, 1),
            )
        fig.tight_layout()
        fig.savefig(OUT / "service_calibration.png", dpi=150)
        plt.close(fig)
