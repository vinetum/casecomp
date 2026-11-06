"""Generate only claims cross-checked by the independent audit."""

from pathlib import Path
import json
import pandas as pd
import numpy as np
from .audit_independent import ROOT

out = ROOT / "artifacts"
claims = []


def claim(name, value, unit, path, scope):
    claims.append(
        dict(claim=name, value=value, unit=unit, source_path=path, qualification=scope)
    )


oracle = json.loads((out / "audit_oracle_results.json").read_text())
claim(
    "submission_rows",
    oracle["submission"]["rows"],
    "rows",
    "artifacts/audit_oracle_results.json",
    "Exact official template and independent capacity/cost audit",
)
claim(
    "total_projected_cost",
    oracle["submission"]["cost_decimal"],
    "USD",
    "artifacts/audit_decimal_cost_trace.csv",
    "Sum of three alternative scenario plans; not one week of realized spending",
)
claim(
    "dominated_official_groups",
    oracle["dominated_groups"],
    "groups",
    "artifacts/audit_exhaustive_groups.csv",
    "Exhaustive cost/service comparison over all source-feasible triples",
)
claim(
    "exhaustive_feasible_triples",
    oracle["candidate_triples"],
    "allocations",
    "artifacts/audit_exhaustive_groups.csv",
    "Sum across 189 independent groups; not Monte Carlo simulations",
)
b = pd.read_csv(out / "forecast_backtests.csv")
b["error"] = abs(b.actual - b.prediction)
ev = (
    b.groupby(["method", "store_id", "dept_id"])
    .apply(
        lambda d: pd.Series(
            {"wape": d.error.sum() / d.actual.sum(), "mae": d.error.mean()}
        ),
        include_groups=False,
    )
    .reset_index()
)
ev.to_csv(out / "audit_forecast_metrics.csv", index=False)
for method, d in ev.groupby("method"):
    claim(
        "macro_WAPE_" + method,
        d.wape.mean(),
        "ratio",
        "artifacts/audit_forecast_metrics.csv",
        "Past-only weekly-origin selection evidence, not future actual performance",
    )
h = pd.read_csv(ROOT / "v_ShiftHistory.csv")
for dept, d in h[h.is_open == 1].groupby("dept_id"):
    claim(
        "historical_attainment_" + str(dept),
        (d.metric_value <= d.target_value).mean(),
        "ratio",
        "v_ShiftHistory.csv",
        "Simulated historical actual outcomes",
    )
for r in pd.read_csv(out / "scenario_summary.csv").itertuples():
    for name in ["cost", "modeled_service", "infeasible_draft_groups"]:
        claim(
            r.scenario_code + "_" + name,
            getattr(r, name),
            (
                "USD"
                if name == "cost"
                else "ratio" if name == "modeled_service" else "groups"
            ),
            "artifacts/scenario_summary.csv",
            "Model projection, equal-weight open blocks; infeasible draft is hypothetical",
        )
if (out / "demonstration_snapshot.json").exists():
    d = json.loads((out / "demonstration_snapshot.json").read_text())
    a = d["last_worker"]["recommendation"]
    if a:
        for name in ["recipient_gain", "donor_effect", "incremental_cost"]:
            claim(
                "Last_Worker_" + name,
                a[name],
                "USD" if name == "incremental_cost" else "probability_delta",
                "artifacts/demonstration_snapshot.json",
                "Warehouse 2 / Feb 13 / OPEN / DISRUPT / Balanced; modeled marginal effect, not causal",
            )
pd.DataFrame(claims).to_csv(out / "verified_presentation_claims.csv", index=False)
