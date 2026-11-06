import itertools
import numpy as np
import pandas as pd
import pytest
from backend.data import KEY, GROUP, read
from backend.optimizer import GroupOptimizer
from backend.verify import verify_totals, validate_submission


def group(engine, scenario=3):
    d = engine.grid
    return d[
        (d.scenario_id == scenario)
        & (d.store_id == 2)
        & (d.day_date == "2026-02-13")
        & (d.shift_code == "OPEN")
    ].copy()


def total_frame(g, allocations):
    return g[KEY].merge(
        pd.DataFrame(
            [
                {"dept_id": a["dept_id"], "submitted_employees": a["employees"]}
                for a in allocations
            ]
        ),
        on="dept_id",
    )


def test_all_official_rows_independently_feasible_and_costed(engine):
    totals = engine.allocations[KEY + ["employees"]].rename(
        columns={"employees": "submitted_employees"}
    )
    v = verify_totals(engine.grid, totals)
    assert v["valid"], v["errors"]
    independent = pd.DataFrame(v["allocations"]).sort_values(KEY)
    actual = engine.allocations.sort_values(KEY)
    for c in ["regular", "flex", "overtime", "cost"]:
        np.testing.assert_allclose(actual[c], independent[c], atol=1e-8)
    assert actual.solver_status.eq("OPTIMAL").all()


def test_source_cost_formula_and_unused_partner_fixture(engine):
    g = group(engine)
    g.loc[
        g.dept_id == 38,
        [
            "available_regular_employees",
            "cross_trained_flex_employees",
            "max_overtime_employees",
        ],
    ] = [8, 2, 3]
    g.loc[
        g.dept_id == 92,
        [
            "available_regular_employees",
            "cross_trained_flex_employees",
            "max_overtime_employees",
        ],
    ] = [10, 2, 3]
    g.loc[
        g.dept_id == 95, ["available_regular_employees", "max_overtime_employees"]
    ] = [4, 2]
    totals = g[KEY].copy()
    totals["submitted_employees"] = totals.dept_id.map({38: 11, 92: 8, 95: 3})
    v = verify_totals(g, totals)
    assert v["valid"]
    fe = next(r for r in v["allocations"] if r["dept_id"] == 38)
    source = g[g.dept_id == 38].iloc[0]
    assert (fe["regular"], fe["flex"], fe["overtime"]) == (8, 2, 1)
    assert fe["cost"] == source.paid_hours * (
        10 * source.loaded_regular_hourly_cost + source.loaded_overtime_hourly_cost
    )
    # Exhausting the lender removes the flex option, without creating workers.
    totals.loc[totals.dept_id == 92, "submitted_employees"] = 10
    fe = next(r for r in verify_totals(g, totals)["allocations"] if r["dept_id"] == 38)
    assert (fe["regular"], fe["flex"], fe["overtime"]) == (8, 0, 3)


@pytest.mark.parametrize("bad", [-1, 1.5, np.nan, 10000])
def test_rejects_invalid_total_counts(engine, bad):
    g = group(engine)
    t = g[KEY].copy()
    t["submitted_employees"] = g.min_staff.astype(float)
    t.iloc[0, t.columns.get_loc("submitted_employees")] = bad
    assert not verify_totals(g, t)["valid"]


def test_rejects_double_counted_flex_and_pharmacy_borrowing(engine):
    g = group(engine)
    t = g[KEY].copy()
    t["submitted_employees"] = (
        g.available_regular_employees + g.max_overtime_employees + 1
    )
    assert not verify_totals(g, t)["valid"]
    assert g[g.dept_id == 95].cross_trained_flex_employees.eq(0).all()


@pytest.mark.parametrize("factor", [0.0, 0.2, 0.5, 1.0])
def test_minimum_conflicts_are_honest_without_capacity_violation(engine, factor):
    g = group(engine)
    for c in [
        "available_regular_employees",
        "max_overtime_employees",
        "cross_trained_flex_employees",
    ]:
        g[c] = np.floor(g[c] * factor).astype(int)
    opt = GroupOptimizer(g, engine.service)
    p = opt.solve()
    t = total_frame(g, p["allocations"])
    assert verify_totals(g, t, require_minimum=False)["valid"]
    full = verify_totals(g, t)
    assert full["valid"] == (p["minimum_staffing_shortfall"] == 0)
    assert opt.certificate(p)["status"] == (
        "FEASIBLE" if full["valid"] else "MINIMUM_CONFLICT"
    )


def test_integer_optimum_against_independent_exhaustive_small_fixture(engine):
    g = group(engine, 1)
    # Small source-derived cost / demand instance permits exhaustive independent enumeration.
    g["available_regular_employees"] = g.dept_id.map({38: 6, 92: 6, 95: 3})
    g["max_overtime_employees"] = 1
    g["cross_trained_flex_employees"] = g.dept_id.map({38: 1, 92: 1, 95: 0})
    g["demand"] *= 0.25
    g["demand_low"] = g.demand * 0.9
    g["demand_high"] = g.demand * 1.1
    candidates = []
    for n in itertools.product(range(9), range(9), range(5)):
        t = g[KEY].copy()
        t["submitted_employees"] = t.dept_id.map(dict(zip([38, 92, 95], n)))
        v = verify_totals(g, t)
        if not v["valid"]:
            continue
        score = sum(
            round(
                float(
                    engine.service.probability(r.dept_id, r.demand, count, r.paid_hours)
                )
                * 10000
            )
            for r, count in zip(g.sort_values("dept_id").itertuples(), n)
        )
        candidates.append((score, sum(a["cost"] for a in v["allocations"])))
    best = max(s for s, c in candidates)
    floor = best - round(0.02 * 3 * 10000)
    minimum = min(round(c * 1000) for s, c in candidates if s >= floor)
    opt = GroupOptimizer(g, engine.service)
    plan = opt.solve(0.02)
    assert plan["objective_cost_mills"] == minimum
    assert opt.max_score == best


def test_frontier_nondomination_and_eligible_last_worker(engine):
    d = engine.decision(3, 2, "2026-02-13", "OPEN", "Balanced")
    g = group(engine)
    for p in d["frontier"]:
        assert verify_totals(g, total_frame(g, p["allocations"]))["valid"]
        assert not any(
            q["cost"] < p["cost"] - 1e-6 and q["service"] >= p["service"]
            for q in d["frontier"]
        )
    before = {a["dept_id"]: a for a in d["plan"]["allocations"]}
    for option in d["last_worker"]["alternatives"]:
        assert verify_totals(g, total_frame(g, option["allocations"]))["valid"]
        after = {a["dept_id"]: a for a in option["allocations"]}
        changes = {i: after[i]["employees"] - before[i]["employees"] for i in before}
        assert changes[option["recipient"]] == 1
        if option["donor"] is not None:
            assert (
                changes[option["donor"]] == -1
                and option["donor"] != 95
                and option["recipient"] != 95
            )
        else:
            assert sum(changes.values()) == 1
        gain = sum(
            (after[i]["probability"] or 0) - (before[i]["probability"] or 0)
            for i in before
        )
        assert abs(gain - option["net_expected_targets_gain"]) < 1e-12


def test_export_exact_template_and_mutations_rejected(engine):
    t = engine.submission("TEST_TEAM")
    v = validate_submission(t)
    assert v["valid"] and v["rows"] == 567
    assert t.loc[t.is_open == 0, "submitted_employees"].eq(0).all()
    assert (
        t.submitted_employees.ge(0).all() and t.submitted_employees.mod(1).eq(0).all()
    )
    bad = t.copy()
    bad.loc[bad.is_open == 0, "submitted_employees"] = 1
    assert not validate_submission(bad)["valid"]
    assert not validate_submission(t.iloc[::-1].reset_index(drop=True))["valid"]
    assert not validate_submission(t.iloc[:-1])["valid"]
    assert not validate_submission(t.assign(team_id=""))["valid"]


def test_independently_reproduces_draft_conflicts(engine):
    g = engine.grid
    t = g[KEY + ["draft_scheduled_employees"]].rename(
        columns={"draft_scheduled_employees": "submitted_employees"}
    )
    counts = {}
    for key, d in g.groupby(GROUP):
        mask = (t[GROUP] == pd.Series(dict(zip(GROUP, key)))).all(axis=1)
        if not verify_totals(d, t[mask])["valid"]:
            counts[key[0]] = counts.get(key[0], 0) + 1
    summary = {s["scenario_id"]: s["infeasible_draft_groups"] for s in engine.summary}
    assert all(summary[i] == counts.get(i, 0) for i in [1, 2, 3])


def test_low_probability_plateau_preserves_strongest_workload_coverage(engine):
    g = group(engine, 1)
    g["demand"] *= 3
    g["demand_low"] = g.demand * 0.9
    g["demand_high"] = g.demand * 1.1
    opt = GroupOptimizer(g, engine.service)
    p = opt.solve()
    assert verify_totals(g, total_frame(g, p["allocations"]))["valid"]
    assert sum(a["employees"] for a in p["allocations"]) > int(g.min_staff.sum())
    # Equal clipped service probabilities must not cause near-empty departments for cost savings.
    assert p["solver_status"] == "OPTIMAL"
