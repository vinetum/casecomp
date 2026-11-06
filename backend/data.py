"""Source loading and fail-closed audits; no source files are modified."""

from pathlib import Path
import hashlib
import json
import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "data/raw"
OUT = ROOT / "artifacts"
KEY = ["scenario_id", "store_id", "dept_id", "day_date", "shift_code"]
BLOCK = KEY[1:]
GROUP = ["scenario_id", "store_id", "day_date", "shift_code"]
DEPTS = {38: "Front End", 92: "Merchandising", 95: "Pharmacy"}


def read(name):
    return pd.read_csv(RAW / f"{name}.csv")


def native(value):
    """Convert scientific scalar types at the JSON boundary without changing calculations."""
    if isinstance(value, np.generic):
        return value.item()
    if isinstance(value, dict):
        return {native(k): native(v) for k, v in value.items()}
    if isinstance(value, (list, tuple)):
        return [native(v) for v in value]
    return value


def write_json(path, value):
    Path(path).write_text(
        json.dumps(
            value,
            indent=2,
            allow_nan=False,
            default=lambda v: v.item() if isinstance(v, np.generic) else str(v),
        )
    )


def audit():
    checks = []

    def check(name, passed, detail=""):
        checks.append(dict(check=name, passed=bool(passed), detail=str(detail)))

    h, g, t = (
        read("v_ShiftHistory"),
        read("v_PlanningWeekGrid"),
        read("TEAM_SUBMISSION_TEMPLATE"),
    )
    counts = {
        "v_ShiftHistory": 1134,
        "v_PlanningWeekGrid": 567,
        "TEAM_SUBMISSION_TEMPLATE": 567,
        "PlanningWeek_BenchmarkForecast": 63,
        "comp_FactShiftDemand": 1134,
        "comp_FactShiftSchedule": 1323,
        "comp_FactShiftAvailability": 1701,
        "comp_FactShiftServiceLevel": 1134,
        "comp_ScenarioDemandAdjustment": 567,
        "comp_ShiftDefinition": 27,
        "comp_LaborStandard": 3,
        "comp_LaborCostAssumption": 9,
        "comp_Scenario": 4,
        "comp_ServiceMetricDefinition": 3,
        "comp_DimShift": 3,
        "DATA_DICTIONARY": 91,
    }
    keys = {
        "comp_FactShiftSchedule": BLOCK + ["schedule_type"],
        "comp_ShiftDefinition": ["dept_id", "day_type", "shift_code"],
        "comp_LaborStandard": ["dept_id"],
        "comp_LaborCostAssumption": ["store_id", "dept_id"],
        "comp_Scenario": ["scenario_id"],
        "comp_ServiceMetricDefinition": ["dept_id"],
        "comp_DimShift": ["shift_code"],
        "DATA_DICTIONARY": ["table_or_object", "column"],
        "PlanningWeek_BenchmarkForecast": ["store_id", "dept_id", "day_date"],
    }
    hashes = {}
    for name, n in counts.items():
        d = read(name)
        k = keys.get(name, KEY if "scenario_id" in d else BLOCK)
        check(
            f"{name}: rows / unique keys",
            len(d) == n and not d.duplicated(k).any(),
            len(d),
        )
        hashes[name] = hashlib.sha256((RAW / f"{name}.csv").read_bytes()).hexdigest()
        check(
            f"{name}: preserved original",
            (ROOT / f"{name}.csv").read_bytes() == (RAW / f"{name}.csv").read_bytes(),
        )
    for name in ["v_ShiftHistory", "v_PlanningWeekGrid"]:
        d = read(name)
        check(
            f"{name}: complete numeric fields",
            d[
                [
                    "store_id",
                    "dept_id",
                    "is_open",
                    "paid_hours",
                    "min_staff",
                    "available_regular_employees",
                    "max_overtime_employees",
                    "cross_trained_flex_employees",
                ]
            ]
            .notna()
            .all()
            .all(),
        )
        for c in [
            "store_id",
            "dept_id",
            "is_open",
            "min_staff",
            "available_regular_employees",
            "max_overtime_employees",
            "cross_trained_flex_employees",
        ]:
            check(f"{name}: integer {c}", ((d[c] >= 0) & (d[c] % 1 == 0)).all())
        check(
            f"{name}: department labels",
            d.department_group.notna().all() and set(d.dept_id) == set(DEPTS),
        )
        check(
            f"{name}: pharmacy qualifications",
            d.loc[d.dept_id == 95, "cross_trained_flex_employees"].eq(0).all(),
        )
    check(
        "template matches grid keys and metadata",
        g[t.columns.drop(["team_id", "submitted_employees"])].equals(
            t.drop(columns=["team_id", "submitted_employees"])
        ),
    )
    check(
        "historical range",
        h.day_date.min() == "2026-01-01"
        and h.day_date.max() == "2026-02-11"
        and h.day_date.nunique() == 42,
    )
    check(
        "planning range",
        g.day_date.min() == "2026-02-12"
        and g.day_date.max() == "2026-02-18"
        and g.day_date.nunique() == 7,
    )
    check("no training / planning overlap", h.day_date.max() < g.day_date.min())
    check(
        "scenario codes",
        g.groupby("scenario_id").scenario_code.first().to_dict()
        == {1: "BASE", 2: "PEAK", 3: "DISRUPT"},
    )
    check(
        "historical daily reconciliation",
        np.allclose(
            h.groupby(["store_id", "dept_id", "day_date"]).shift_demand_units.sum(),
            h.groupby(["store_id", "dept_id", "day_date"]).daily_demand_units.first(),
            atol=1e-4,
        ),
    )
    check(
        "historical closed demand/staff",
        h.loc[h.is_open == 0, ["shift_demand_units", "worked_employees"]]
        .eq(0)
        .all()
        .all(),
    )
    check(
        "historical labels open only",
        h.loc[h.is_open == 1, "met_target"].notna().all()
        and h.loc[h.is_open == 0, "met_target"].isna().all(),
    )
    check(
        "historical service labels",
        h.loc[h.is_open == 1, "met_target"]
        .eq(
            (
                h.loc[h.is_open == 1, "metric_value"]
                <= h.loc[h.is_open == 1, "target_value"]
            ).astype(int)
        )
        .all(),
    )
    check(
        "historical worked accounting",
        h.worked_employees.eq(
            h.scheduled_employees - h.callout_employees + h.backfill_employees
        ).all(),
    )
    hd = h.merge(
        read("comp_FactShiftDemand"),
        on=BLOCK,
        suffixes=("", "_source"),
        validate="one_to_one",
    )
    check(
        "historical demand source",
        np.allclose(hd.shift_demand_units, hd.demand_units)
        and hd.is_open.eq(hd.is_open_source).all(),
    )
    hs = h.merge(
        read("comp_FactShiftServiceLevel"),
        on=BLOCK,
        suffixes=("", "_source"),
        validate="one_to_one",
    )
    check(
        "historical service source",
        np.allclose(hs.metric_value, hs.metric_value_source, equal_nan=True)
        and np.allclose(hs.met_target, hs.met_target_source, equal_nan=True),
    )
    schedule = read("comp_FactShiftSchedule")
    actual = schedule[schedule.schedule_type == "Actual"]
    ha = h.merge(actual, on=BLOCK, suffixes=("", "_source"), validate="one_to_one")
    for col in [
        "worked_employees",
        "worked_labor_hours",
        "worked_regular_hours",
        "worked_overtime_hours",
    ]:
        check(
            "historical schedule source " + col,
            np.allclose(ha[col], ha[col + "_source"]),
        )
    check(
        "historical productive hours",
        np.allclose(h.worked_labor_hours, h.worked_employees * h.paid_hours),
    )
    check(
        "historical regular plus OT hours",
        np.allclose(
            h.worked_labor_hours, h.worked_regular_hours + h.worked_overtime_hours
        ),
    )
    draft = g.merge(
        schedule[schedule.schedule_type == "Draft"], on=BLOCK, validate="many_to_one"
    )
    check(
        "planning draft source",
        draft.draft_scheduled_employees.eq(draft.scheduled_employees).all(),
    )
    check(
        "planning closed availability",
        g.loc[
            g.is_open == 0,
            ["paid_hours", "available_regular_employees", "max_overtime_employees"],
        ]
        .eq(0)
        .all()
        .all(),
    )
    check("open shift durations", (g.loc[g.is_open == 1, "paid_hours"] > 0).all())
    defs = read("comp_ShiftDefinition")
    merged = g.merge(
        defs,
        on=["dept_id", "day_type", "shift_code"],
        suffixes=("", "_source"),
        validate="many_to_one",
    )
    for c in ["paid_hours", "is_open", "min_staff"]:
        check("shift definition " + c, merged[c].eq(merged[c + "_source"]).all())
    adj = g.merge(
        read("comp_ScenarioDemandAdjustment"),
        on=KEY,
        suffixes=("", "_source"),
        validate="one_to_one",
    )
    check(
        "exact official multipliers",
        adj.demand_multiplier.eq(adj.demand_multiplier_source).all(),
    )
    check(
        "BASE / DISRUPT workload multiplier",
        g.loc[g.scenario_id.isin([1, 3]), "demand_multiplier"].eq(1).all(),
    )
    a = g.merge(
        read("comp_FactShiftAvailability"),
        on=KEY,
        suffixes=("", "_source"),
        validate="one_to_one",
    )
    for c in [
        "available_regular_employees",
        "max_overtime_employees",
        "cross_trained_flex_employees",
    ]:
        check("availability source " + c, a[c].eq(a[c + "_source"]).all())
    c = read("comp_LaborCostAssumption")
    check(
        "regular loaded rates",
        np.allclose(
            c.loaded_regular_hourly_cost,
            (c.base_hourly_wage * (1 + c.regular_burden_pct)).round(2),
        ),
    )
    check(
        "overtime loaded rates",
        np.allclose(
            c.loaded_overtime_hourly_cost,
            (
                c.base_hourly_wage * c.overtime_multiplier * (1 + c.overtime_burden_pct)
            ).round(2),
        ),
    )
    rates = g.merge(c, on=["store_id", "dept_id"], suffixes=("", "_source"))
    for col in ["loaded_regular_hourly_cost", "loaded_overtime_hourly_cost"]:
        check("grid source " + col, rates[col].eq(rates[col + "_source"]).all())
    sheets = {
        "ShiftHistory": "v_ShiftHistory",
        "PlanningWeekGrid": "v_PlanningWeekGrid",
        "BenchmarkForecast": "PlanningWeek_BenchmarkForecast",
        "ShiftDefinition": "comp_ShiftDefinition",
        "LaborStandard": "comp_LaborStandard",
        "ServiceMetric": "comp_ServiceMetricDefinition",
        "LaborCost": "comp_LaborCostAssumption",
        "Scenario": "comp_Scenario",
        "DataDictionary": "DATA_DICTIONARY",
    }
    for sheet, name in sheets.items():
        x = pd.read_excel(
            RAW / "Costco_Workforce_Case_Student_DataPack.xlsx", sheet_name=sheet
        )
        check(
            "workbook matches " + sheet,
            x.fillna("").astype(str).equals(read(name).fillna("").astype(str)),
        )
    result = {
        "passed": all(c["passed"] for c in checks),
        "checks": checks,
        "source_sha256": hashes,
        "historical_open_blocks": int(h.is_open.sum()),
        "planning_open_blocks": int(g.is_open.sum()),
    }
    OUT.mkdir(exist_ok=True)
    write_json(OUT / "data_audit.json", result)
    (OUT / "data_audit.md").write_text(
        "# Source audit\n\n"
        + "\n".join(
            f"- {'PASS' if c['passed'] else 'FAIL'}: {c['check']} {c['detail']}".rstrip()
            for c in checks
        )
    )
    if not result["passed"]:
        raise ValueError("Source audit failed; see artifacts/data_audit.json")
    return result
