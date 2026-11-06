"""Independent total-headcount verifier; deliberately imports no solver code."""

import numpy as np
import pandas as pd
from .data import KEY, GROUP, read


def verify_totals(grid, totals, require_minimum=True):
    errors = []
    allocations = []
    if (
        len(totals) != len(grid)
        or totals.duplicated(KEY).any()
        or set(map(tuple, totals[KEY].to_numpy()))
        != set(map(tuple, grid[KEY].to_numpy()))
    ):
        return {
            "valid": False,
            "errors": ["Row keys are not an exact unique match"],
            "allocations": [],
        }
    d = grid.merge(totals[KEY + ["submitted_employees"]], on=KEY, validate="one_to_one")
    values = pd.to_numeric(d.submitted_employees, errors="coerce")
    if not (
        np.isfinite(values)
        & (values >= 0)
        & (values % 1 == 0)
        & (values <= np.iinfo(np.int64).max // 2)
    ).all():
        return {
            "valid": False,
            "errors": ["All employee counts must be finite nonnegative integers"],
            "allocations": [],
        }
    d["submitted_employees"] = values.astype(int)
    for key, group in d.groupby(GROUP, sort=False):
        rows = {int(r.dept_id): r for r in group.itertuples()}
        for dept, r in rows.items():
            n = r.submitted_employees
            prefix = f"{key} / department {dept}"
            if not np.isfinite(n) or n < 0 or n % 1:
                errors.append(prefix + ": nonnegative integer required")
                continue
            n = int(n)
            reg = min(n, int(r.available_regular_employees))
            flex = 0
            if dept in (38, 92):
                partner = rows[92 if dept == 38 else 38]
                free = max(
                    0,
                    int(partner.available_regular_employees)
                    - int(partner.submitted_employees),
                )
                flex = min(max(0, n - reg), int(r.cross_trained_flex_employees), free)
            ot = n - reg - flex
            issues = []
            if not r.is_open and n:
                issues.append("closed block must be zero")
            if r.is_open and n < r.min_staff and require_minimum:
                issues.append("below minimum staffing")
            if ot > r.max_overtime_employees:
                issues.append("overtime / shared workforce capacity exceeded")
            errors.extend(prefix + ": " + s for s in issues)
            cost = (
                (reg + flex) * r.paid_hours * r.loaded_regular_hourly_cost
                + ot * r.paid_hours * r.loaded_overtime_hourly_cost
            )
            allocations.append(
                dict(zip(GROUP, key))
                | {
                    "dept_id": dept,
                    "regular": reg,
                    "flex": flex,
                    "overtime": ot,
                    "employees": n,
                    "cost": float(cost),
                    "valid": not issues,
                }
            )
    return {"valid": not errors, "errors": errors, "allocations": allocations}


def validate_submission(frame, grid=None):
    template = read("TEAM_SUBMISSION_TEMPLATE")
    grid = read("v_PlanningWeekGrid") if grid is None else grid
    errors = []
    if list(frame.columns) != list(template.columns):
        errors.append("Columns/order differ from original template")
    if len(frame) != 567:
        errors.append("Expected exactly 567 rows")
    fixed = [c for c in template if c not in ["team_id", "submitted_employees"]]
    if any(c not in frame for c in template):
        return {
            "valid": False,
            "rows": len(frame),
            "errors": errors + ["Missing columns"],
        }
    if not frame[fixed].reset_index(drop=True).equals(template[fixed]):
        errors.append("Template metadata or original row order changed")
    if (
        frame.team_id.isna().any()
        or frame.team_id.astype(str).str.strip().eq("").any()
        or frame.team_id.nunique() != 1
    ):
        errors.append("Exactly one nonempty team ID required")
    result = verify_totals(grid, frame)
    errors += result["errors"]
    return {
        "valid": not errors,
        "rows": len(frame),
        "errors": errors,
        "recalculated_cost": sum(r["cost"] for r in result["allocations"]),
    }
