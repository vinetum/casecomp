"""Application orchestration, reproducible artifacts and traceable decisions."""

from functools import lru_cache
import numpy as np
import pandas as pd
from .data import audit, read, OUT, KEY, GROUP, write_json
from .forecast import Forecast
from .service import Service
from .optimizer import GroupOptimizer, MODES
from .verify import verify_totals, validate_submission


def records(d):
    return (
        d.replace([np.inf, -np.inf], np.nan)
        .astype(object)
        .where(pd.notna(d), None)
        .to_dict("records")
    )


class Engine:
    def __init__(self, diagnostics=True):
        self.audit = audit()
        self.forecast = Forecast()
        self.service = Service(diagnostics=diagnostics)
        self.grid = self.forecast.planning
        self.metrics = {
            "forecast": self.forecast.metrics,
            "service": self.service.metrics,
        }
        write_json(OUT / "model_metrics.json", self.metrics)
        self.plans = {}
        self.generate()

    @lru_cache(maxsize=64)
    def decision(
        self,
        scenario_id,
        store_id,
        day_date,
        shift_code,
        mode="Service First",
        demand_factor=1.0,
        availability_factor=1.0,
        uncertainty="central",
    ):
        g = self.grid[
            (self.grid.scenario_id == scenario_id)
            & (self.grid.store_id == store_id)
            & (self.grid.day_date == day_date)
            & (self.grid.shift_code == shift_code)
        ].copy()
        if len(g) != 3:
            raise ValueError("Unknown warehouse/date/shift/scenario")
        if mode not in MODES:
            raise ValueError("Unknown operating mode")
        field = {"central": "demand", "lower": "demand_low", "upper": "demand_high"}[
            uncertainty
        ]
        g["demand"] = g[field] * demand_factor
        g["demand_low"] = g.demand * (1 - g.relative_stress).clip(lower=0)
        g["demand_high"] = g.demand * (1 + g.relative_stress)
        for c in [
            "available_regular_employees",
            "max_overtime_employees",
            "cross_trained_flex_employees",
        ]:
            g[c] = np.floor(g[c] * availability_factor).astype(int)
        optimizer = GroupOptimizer(g, self.service)
        plan = optimizer.solve(MODES[mode])
        totals = g[KEY].merge(
            pd.DataFrame(
                [
                    {"dept_id": r["dept_id"], "submitted_employees": r["employees"]}
                    for r in plan["allocations"]
                ]
            ),
            on="dept_id",
        )
        verified = verify_totals(g, totals)
        certificate = optimizer.certificate(plan)
        certificate["independent_verification"] = {
            "valid": verified["valid"],
            "errors": verified["errors"],
        }
        certificate["capacity_verified"] = verify_totals(
            g, totals, require_minimum=False
        )["valid"]
        draft = g[KEY + ["draft_scheduled_employees"]].rename(
            columns={"draft_scheduled_employees": "submitted_employees"}
        )
        vd = verify_totals(g, draft)
        draft_rows = []
        for r in g.sort_values("dept_id").itertuples():
            p = (
                float(
                    self.service.probability(
                        r.dept_id, r.demand, r.draft_scheduled_employees, r.paid_hours
                    )
                )
                if r.is_open
                else None
            )
            alloc = next(a for a in vd["allocations"] if a["dept_id"] == r.dept_id)
            draft_rows.append(alloc | {"probability": p})
        draft_cost = sum(a["cost"] for a in draft_rows)
        explanation = (
            f"{mode} assigns {sum(a['employees'] for a in plan['allocations'])} block employees at ${plan['cost']:,.2f}, "
            f"a ${plan['cost']-draft_cost:+,.2f} change from the draft. Mean modeled target attainment across open departments is {plan['service']:.1%}. "
            f"The cost-minimizing CP-SAT solution allows {MODES[mode]:.0%} mean attainment loss from the maximum, after minimizing safety shortfalls. "
            + (
                "Independent workforce checks pass. "
                if verified["valid"]
                else "Minimum staffing cannot be achieved; do not export this simulation. "
            )
            + (
                "Draft is non-executable under these availability constraints. "
                if not vd["valid"]
                else ""
            )
            + "Service probabilities are estimates, not guaranteed wait times. If modeled service is at its lower bound, extra workers have unvalidated marginal value; review the stress range and capacity certificate before operational use."
        )
        return {
            "selection": dict(
                scenario_id=scenario_id,
                store_id=store_id,
                day_date=day_date,
                shift_code=shift_code,
                mode=mode,
                demand_factor=demand_factor,
                availability_factor=availability_factor,
                uncertainty=uncertainty,
            ),
            "plan": plan,
            "draft": {
                "valid": vd["valid"],
                "errors": vd["errors"],
                "cost": draft_cost,
                "allocations": draft_rows,
            },
            "certificate": certificate,
            "last_worker": optimizer.last_worker(plan),
            "frontier": optimizer.frontier(),
            "explanation": explanation,
        }

    def generate(self):
        # Full official Service First export: no manual scenario overrides.
        allocations = []
        comparisons = []
        certs = []
        drafts = []
        for key, g in self.grid.groupby(GROUP, sort=True):
            optimizer = GroupOptimizer(g, self.service)
            plan = optimizer.solve(0.0)
            totals = g[KEY].merge(
                pd.DataFrame(
                    [
                        {"dept_id": r["dept_id"], "submitted_employees": r["employees"]}
                        for r in plan["allocations"]
                    ]
                ),
                on="dept_id",
            )
            v = verify_totals(g, totals)
            if not v["valid"]:
                raise ValueError(f'Official plan infeasible: {v["errors"]}')
            draft = g[KEY + ["draft_scheduled_employees"]].rename(
                columns={"draft_scheduled_employees": "submitted_employees"}
            )
            vd = verify_totals(g, draft)
            drafts.append(
                dict(zip(GROUP, key)) | {"valid": vd["valid"], "errors": vd["errors"]}
            )
            for r in plan["allocations"]:
                source = g[g.dept_id == r["dept_id"]].iloc[0]
                da = next(a for a in vd["allocations"] if a["dept_id"] == r["dept_id"])
                dp = (
                    float(
                        self.service.probability(
                            r["dept_id"],
                            source.demand,
                            source.draft_scheduled_employees,
                            source.paid_hours,
                        )
                    )
                    if source.is_open
                    else None
                )
                allocations.append(
                    dict(zip(GROUP, key)) | r | {"solver_status": plan["solver_status"]}
                )
                comparisons.append(
                    dict(zip(GROUP, key))
                    | {
                        "dept_id": r["dept_id"],
                        "draft_employees": int(source.draft_scheduled_employees),
                        "recommended_employees": r["employees"],
                        "draft_cost_hypothetical": da["cost"],
                        "recommended_cost": r["cost"],
                        "draft_probability": dp,
                        "recommended_probability": r["probability"],
                        "draft_group_executable": vd["valid"],
                    }
                )
            certs.append(dict(zip(GROUP, key)) | optimizer.certificate(plan))
        self.allocations = pd.DataFrame(allocations)
        self.comparison = pd.DataFrame(comparisons)
        self.allocations.to_csv(OUT / "optimized_allocations.csv", index=False)
        self.comparison.to_csv(OUT / "plan_vs_draft.csv", index=False)
        self.summary = []
        for scenario, d in self.allocations.groupby("scenario_id"):
            c = self.comparison[self.comparison.scenario_id == scenario]
            dd = [r for r in drafts if r["scenario_id"] == scenario]
            self.summary.append(
                {
                    "scenario_id": int(scenario),
                    "scenario_code": {1: "BASE", 2: "PEAK", 3: "DISRUPT"}[scenario],
                    "cost": float(d.cost.sum()),
                    "draft_cost_hypothetical": float(c.draft_cost_hypothetical.sum()),
                    "modeled_service": float(d.probability.mean()),
                    "draft_modeled_service": float(c.draft_probability.mean()),
                    "at_risk_blocks": int((d.probability < 0.95).sum()),
                    "employees": int(d.employees.sum()),
                    "overtime": int(d.overtime.sum()),
                    "flex": int(d.flex.sum()),
                    "infeasible_draft_groups": sum(not x["valid"] for x in dd),
                }
            )
        pd.DataFrame(self.summary).to_csv(OUT / "scenario_summary.csv", index=False)
        write_json(OUT / "feasibility_certificates.json", certs)
        write_json(OUT / "draft_feasibility.json", drafts)
        submission = self.submission("SHIFTWISE")
        submission.to_csv(OUT / "TEAM_SUBMISSION_COMPLETED.csv", index=False)
        self.validation = validate_submission(submission)
        write_json(OUT / "validation_report.json", self.validation)
        if not self.validation["valid"]:
            raise ValueError(self.validation["errors"])
        # Select a demonstration by real scenario staffing divergence, rather than a canned dramatic result.
        pivot = self.allocations.pivot(
            index=["store_id", "day_date", "shift_code", "dept_id"],
            columns="scenario_id",
            values="employees",
        )
        example = pivot.loc[(pivot.max(axis=1) - pivot.min(axis=1)).idxmax()]
        index = example.name
        evidence = {
            "simulated_case_only": True,
            "forecast": self.forecast.metrics,
            "historical_attainment": {
                k: v["historical_attainment"] for k, v in self.service.metrics.items()
            },
            "scenarios": self.summary,
            "submission": self.validation,
            "data_selected_demo": dict(
                zip(["store_id", "day_date", "shift_code", "dept_id"], index)
            ),
            "source_files": [
                "v_ShiftHistory.csv",
                "v_PlanningWeekGrid.csv",
                "comp_LaborStandard.csv",
                "comp_LaborCostAssumption.csv",
                "TEAM_SUBMISSION_TEMPLATE.csv",
            ],
            "scope": "All case data is simulated. Scenario costs are alternatives, not additive realized spending. Service probabilities are model estimates, not causal or guaranteed waits.",
            "limitations": [
                "Short six-week history; two forecast selection origins",
                "Neutral central holiday adjustments; no validated holiday uplift",
                "Sensitivity envelopes are not confidence intervals",
                "Aggregate pools do not establish individual weekly hours or a named roster",
                "Low-probability plateaus have unvalidated marginal capacity value",
            ],
            "audit": "artifacts/INDEPENDENT_AUDIT.md",
            "demo_assets": "artifacts/DEMO_ASSETS",
            "demo_run_of_show": "artifacts/demo_run_of_show.md",
            "live_demo_evidence": "artifacts/DEMO_ASSETS/live_demo_decisions.json",
            "verified_claims": "artifacts/verified_presentation_claims.csv",
            "prior_claim_note": "Preliminary research values were not used as labels or forced outputs. No billion-simulation claim.",
        }
        write_json(OUT / "presentation_evidence.json", evidence)

    def submission(self, team_id):
        t = read("TEAM_SUBMISSION_TEMPLATE")
        merged = t[KEY].merge(
            self.allocations[KEY + ["employees"]],
            on=KEY,
            how="left",
            validate="one_to_one",
        )
        t["submitted_employees"] = merged.employees.astype(int)
        t["team_id"] = team_id
        result = validate_submission(t)
        if not result["valid"]:
            raise ValueError("Submission failed validation")
        return t

    def bootstrap(self):
        daily = self.forecast.daily
        return {
            "metrics": self.metrics,
            "summary": self.summary,
            "validation": self.validation,
            "forecast_evaluation": records(self.forecast.evaluation),
            "historical": records(
                daily[["store_id", "dept_id", "day_date", "daily_demand_units"]]
            ),
            "forecasts": records(
                self.forecast.planning[self.forecast.planning.scenario_id == 1][
                    [
                        "store_id",
                        "dept_id",
                        "day_date",
                        "shift_code",
                        "daily_forecast",
                        "demand",
                        "demand_low",
                        "demand_high",
                        "forecast_method",
                        "calendar_factor_applied",
                        "calendar_analogue_factor",
                        "calendar_support_days",
                    ]
                ]
            ),
            "allocations": records(self.allocations),
            "benchmark": records(self.forecast.benchmark),
            "dates": sorted(self.grid.day_date.unique()),
            "modes": list(MODES),
        }
