"""Prompt 2 oracle. Does not import production allocation/verifier/forecast code.
Enumerates ALL feasible integer triples using source tables and direct model math.
"""

from pathlib import Path
from decimal import Decimal
from itertools import product
import json
import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
KEY = ["scenario_id", "store_id", "dept_id", "day_date", "shift_code"]
GROUP = ["scenario_id", "store_id", "day_date", "shift_code"]


def load(name):
    return pd.read_csv(ROOT / f"{name}.csv")


def probability(service, dept, demand, counts, hours):
    counts = np.asarray(counts)
    kind, m = service.models[int(dept)]
    std = float(
        load("comp_LaborStandard")
        .set_index("dept_id")
        .loc[dept, "labor_hours_per_workload_unit"]
    )
    u = np.divide(
        demand * std,
        counts * hours,
        out=np.full(counts.shape, 10.0, dtype=float),
        where=counts * hours > 0,
    )
    if kind == "logistic":
        z = m.intercept_[0] + m.coef_[0, 0] * u
        p = 1 / (1 + np.exp(np.clip(-z, -700, 700)))
    else:
        p = np.interp(u, m.X_thresholds_, m.y_thresholds_)
    return np.where(counts * hours > 0, np.clip(p, 0.005, 0.995), 0.0)


def enumerate_group(g, service):
    rows = list(g.sort_values("dept_id").itertuples())
    caps = [
        (
            int(
                r.available_regular_employees
                + r.max_overtime_employees
                + r.cross_trained_flex_employees
            )
            if r.is_open
            else 0
        )
        for r in rows
    ]
    n = np.array(list(product(*(range(c + 1) for c in caps))), dtype=int)
    reg = np.minimum(n, np.array([r.available_regular_employees for r in rows]))
    f = np.zeros_like(n)
    for i, j in [(0, 1), (1, 0)]:
        f[:, i] = np.minimum.reduce(
            [
                n[:, i] - reg[:, i],
                np.full(len(n), rows[i].cross_trained_flex_employees),
                np.maximum(rows[j].available_regular_employees - n[:, j], 0),
            ]
        )
    ot = n - reg - f
    valid = np.all(ot <= np.array([r.max_overtime_employees for r in rows]), axis=1)
    deficits = np.maximum(
        np.array([r.min_staff if r.is_open else 0 for r in rows]) - n, 0
    ).sum(axis=1)
    min_deficit = deficits[valid].min()
    valid &= deficits == min_deficit
    n, reg, f, ot = n[valid], reg[valid], f[valid], ot[valid]
    cost = sum(
        (reg[:, i] + f[:, i])
        * float(r.paid_hours)
        * float(r.loaded_regular_hourly_cost)
        + ot[:, i] * float(r.paid_hours) * float(r.loaded_overtime_hourly_cost)
        for i, r in enumerate(rows)
    )
    ps = np.column_stack(
        [
            (
                probability(service, r.dept_id, r.demand, n[:, i], r.paid_hours)
                if r.is_open
                else np.zeros(len(n))
            )
            for i, r in enumerate(rows)
        ]
    )
    return n, cost, ps, int(min_deficit)


def submission_check(frame):
    """Independent raw-template and pool audit with decimal monetary arithmetic."""
    template = load("TEAM_SUBMISSION_TEMPLATE")
    grid = load("v_PlanningWeekGrid")
    errors = []
    cost = Decimal(0)
    if list(frame.columns) != list(template.columns):
        errors.append("columns")
    if len(frame) != 567:
        errors.append("row count")
    fixed = [c for c in template if c not in ["team_id", "submitted_employees"]]
    if not frame[fixed].equals(template[fixed]):
        errors.append("metadata/order")
    if frame.duplicated(KEY).any():
        errors.append("duplicate keys")
    values = pd.to_numeric(frame.submitted_employees, errors="coerce")
    if not (np.isfinite(values) & values.ge(0) & values.mod(1).eq(0)).all():
        return {"valid": False, "errors": errors + ["integer counts"]}
    d = grid.merge(frame[KEY + ["submitted_employees"]], on=KEY, validate="one_to_one")
    trace = []
    for key, g in d.groupby(GROUP):
        rows = {int(r.dept_id): r for r in g.itertuples()}
        for dept, r in rows.items():
            n = int(r.submitted_employees)
            local = min(n, int(r.available_regular_employees))
            incoming = 0
            if dept != 95:
                other = rows[92 if dept == 38 else 38]
                incoming = min(
                    n - local,
                    int(r.cross_trained_flex_employees),
                    max(
                        0,
                        int(
                            other.available_regular_employees
                            - other.submitted_employees
                        ),
                    ),
                )
            overtime = n - local - incoming
            if (
                (not r.is_open and n)
                or (r.is_open and n < r.min_staff)
                or overtime > r.max_overtime_employees
            ):
                errors.append(str(key) + str(dept))
            amount = Decimal(str(r.paid_hours)) * (
                Decimal(str(r.loaded_regular_hourly_cost)) * (local + incoming)
                + Decimal(str(r.loaded_overtime_hourly_cost)) * overtime
            )
            cost += amount
            trace.append(
                dict(zip(GROUP, key))
                | dict(
                    dept_id=dept,
                    regular=local,
                    flex=incoming,
                    overtime=overtime,
                    cost=float(amount),
                )
            )
    return {
        "valid": not errors,
        "errors": errors,
        "rows": len(frame),
        "cost_decimal": str(cost),
        "trace": trace,
    }


def run(engine):
    out = ROOT / "artifacts"
    rows = []
    baselines = []
    marginal_checks = []
    old = pd.read_csv(
        __import__("io").StringIO(
            __import__("subprocess").check_output(
                ["git", "show", "9c66981:artifacts/optimized_allocations.csv"],
                cwd=ROOT,
                text=True,
            )
        )
    )
    for key, g in engine.grid.groupby(GROUP):
        n, cost, ps, deficit = enumerate_group(g, engine.service)
        totalp = ps.sum(axis=1)

        def match(frame):
            d = frame
            for k, v in zip(GROUP, key):
                d = d[d[k] == v]
            return d.sort_values("dept_id")

        current = match(engine.allocations)
        prior = match(old)
        picked = np.where((n == current.employees.to_numpy()).all(axis=1))[0]
        assert len(picked) == 1
        idx = picked[0]
        dom = (cost < cost[idx] - 1e-6) & (totalp >= totalp[idx] - 1e-10)
        prior_counts = prior.employees.to_numpy()
        pi = np.where((n == prior_counts).all(axis=1))[0][0]
        olddom = (cost < cost[pi] - 1e-6) & (totalp >= totalp[pi] - 1e-10)
        rows.append(
            dict(zip(GROUP, key))
            | dict(
                candidates=len(n),
                dominated=bool(dom.any()),
                prior_dominated=bool(olddom.any()),
                prior_excess_cost=(
                    float(cost[pi] - min(cost[olddom])) if olddom.any() else 0.0
                ),
                score_gap=float(totalp.max() - totalp[idx]),
                cost=float(cost[idx]),
                minimum_shortfall=deficit,
            )
        )
        # Challenge every Balanced Last Worker decision against this independent domain.
        from backend.optimizer import GroupOptimizer

        optimizer = GroupOptimizer(g, engine.service)
        plan = optimizer.solve(0.02)
        start = np.array([a["employees"] for a in plan["allocations"]])
        base_idx = np.flatnonzero((n == start).all(axis=1))[0]
        result = optimizer.last_worker(plan)
        expected = set()
        for recipient in range(3):
            for donor in [None] + ([1 - recipient] if recipient < 2 else []):
                candidate = start.copy()
                candidate[recipient] += 1
                if donor is not None:
                    candidate[donor] -= 1
                indices = np.flatnonzero((n == candidate).all(axis=1))
                if len(indices):
                    expected.add(tuple(candidate))
        actual = set()
        for option in result["alternatives"]:
            candidate = tuple(a["employees"] for a in option["allocations"])
            actual.add(candidate)
            j = np.flatnonzero((n == candidate).all(axis=1))[0]
            assert abs(option["incremental_cost"] - (cost[j] - cost[base_idx])) < 1e-7
            assert (
                abs(
                    option["net_expected_targets_gain"] - (totalp[j] - totalp[base_idx])
                )
                < 1e-10
            )
        assert actual == expected, (key, actual, expected)
        if result["recommendation"]:
            assert (
                result["recommendation"]["net_expected_targets_gain"]
                >= max(a["net_expected_targets_gain"] for a in result["alternatives"])
                - 1e-6
            )
        marginal_checks.append(
            dict(zip(GROUP, key)) | {"eligible_options": len(actual), "verified": True}
        )
        # Nearest feasible repair of independently computed utilization heuristics.
        rs = list(g.sort_values("dept_id").itertuples())
        for util in [0.78, 0.82, 0.90]:
            desired = np.array(
                [
                    (
                        max(
                            r.min_staff,
                            int(
                                np.ceil(
                                    r.demand
                                    * engine.service.standards[int(r.dept_id)]
                                    / (r.paid_hours * util)
                                )
                            ),
                        )
                        if r.is_open
                        else 0
                    )
                    for r in rs
                ]
            )
            distance = abs(n - desired).sum(axis=1)
            candidates = np.where(distance == distance.min())[0]
            j = candidates[np.argmin(cost[candidates])]
            baselines.append(
                dict(zip(GROUP, key))
                | dict(
                    utilization=util,
                    cost=float(cost[j]),
                    service=float(totalp[j] / max(1, g.is_open.sum())),
                    optimized_service=float(totalp[idx] / max(1, g.is_open.sum())),
                )
            )
    pd.DataFrame(marginal_checks).to_csv(out / "audit_last_worker.csv", index=False)
    pd.DataFrame(rows).to_csv(out / "audit_exhaustive_groups.csv", index=False)
    pd.DataFrame(baselines).to_csv(out / "audit_heuristic_baselines.csv", index=False)
    sub = submission_check(pd.read_csv(out / "TEAM_SUBMISSION_COMPLETED.csv"))
    trace = pd.DataFrame(sub.pop("trace"))
    trace.to_csv(out / "audit_decimal_cost_trace.csv", index=False)
    report = {
        "submission": sub,
        "groups": len(rows),
        "candidate_triples": sum(r["candidates"] for r in rows),
        "dominated_groups": sum(r["dominated"] for r in rows),
        "prior_dominated_groups": sum(r["prior_dominated"] for r in rows),
        "prior_dominated_excess_cost": sum(r["prior_excess_cost"] for r in rows),
        "max_true_score_gap": max(r["score_gap"] for r in rows),
    }
    (out / "audit_oracle_results.json").write_text(json.dumps(report, indent=2))
    print(report)
    return report


if __name__ == "__main__":
    from backend.engine import Engine

    run(Engine())
