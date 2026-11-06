"""Exact finite-domain CP-SAT optimization with canonical source-defined costing."""

from dataclasses import dataclass
import numpy as np
from ortools.sat.python import cp_model
from .data import DEPTS
from .runtime_budget import solver_seconds

MODES = {"Service First": 0.0, "Balanced": 0.02, "Budget Conscious": 0.06}
SCALE = 1000000


@dataclass
class Choice:
    totals: tuple
    parts: tuple
    cost: float
    score: int
    deficit: int


def canonical(rows, totals):
    parts = []
    cost = 0.0
    for i, (r, n) in enumerate(zip(rows, totals)):
        reg = min(n, int(r.available_regular_employees))
        flex = 0
        if r.dept_id in (38, 92):
            j = 1 - i
            flex = min(
                max(n - reg, 0),
                int(r.cross_trained_flex_employees),
                max(int(rows[j].available_regular_employees) - totals[j], 0),
            )
        ot = n - reg - flex
        if ot > r.max_overtime_employees or (not r.is_open and n):
            return None
        parts.append((reg, flex, ot))
        cost += r.paid_hours * (
            (reg + flex) * r.loaded_regular_hourly_cost
            + ot * r.loaded_overtime_hourly_cost
        )
    return tuple(parts), cost


class GroupOptimizer:
    def __init__(self, group, service):
        self.rows = list(group.sort_values("dept_id").itertuples(index=False))
        self.service = service
        self.open_count = sum(r.is_open for r in self.rows)
        self.probs = {}
        self.tables = []
        for r in self.rows:
            cap = (
                int(
                    r.available_regular_employees
                    + r.max_overtime_employees
                    + r.cross_trained_flex_employees
                )
                if r.is_open
                else 0
            )
            self.probs[int(r.dept_id)] = (
                service.probability(
                    r.dept_id, r.demand, np.arange(cap + 1), r.paid_hours
                )
                if r.is_open
                else np.array([0.0])
            )
        for rows in [self.rows[:2], self.rows[2:]]:
            choices = []
            ranges = [range(len(self.probs[int(r.dept_id)])) for r in rows]
            import itertools

            for totals in itertools.product(*ranges):
                allocation = canonical(rows, totals)
                if allocation is None:
                    continue
                parts, cost = allocation
                score = sum(
                    round(float(self.probs[int(r.dept_id)][n]) * SCALE)
                    for r, n in zip(rows, totals)
                )
                deficit = sum(
                    max(int(r.min_staff) - n, 0)
                    for r, n in zip(rows, totals)
                    if r.is_open
                )
                choices.append(Choice(totals, parts, cost, score, deficit))
            # Lexicographic safety: minimum total safety shortfall precedes service.
            floor = min(c.deficit for c in choices)
            self.tables.append([c for c in choices if c.deficit == floor])
        self.min_deficit = sum(t[0].deficit for t in self.tables)
        self.max_score = sum(max(c.score for c in t) for t in self.tables)

    def solve(self, tolerance=0.0):
        model = cp_model.CpModel()
        allvars = []
        costs = []
        scores = []
        loss = round(tolerance * self.open_count * SCALE)
        for ti, table in enumerate(self.tables):
            # Exact domain pruning: other independent components cannot exceed
            # their own maxima, so no feasible global solution can use these rows.
            component_max = max(c.score for c in table)
            table = [c for c in table if c.score >= component_max - loss]
            values = []
            for c in table:
                values.append(
                    [v for n, p in zip(c.totals, c.parts) for v in (n, *p)]
                    + [round(c.cost * 1000), c.score]
                )
            cols = list(zip(*values))
            vs = [
                model.new_int_var(min(col), max(col), f"t{ti}_v{j}")
                for j, col in enumerate(cols)
            ]
            model.add_allowed_assignments(vs, values)
            allvars.append(vs)
            costs.append(vs[-2])
            scores.append(vs[-1])
        model.add(sum(scores) >= self.max_score - loss)
        model.minimize(sum(costs))
        solver = cp_model.CpSolver()
        solver.parameters.num_search_workers = 1
        solver.parameters.random_seed = 26
        solver.parameters.max_time_in_seconds = solver_seconds()
        status = solver.solve(model)
        if status != cp_model.OPTIMAL:
            raise RuntimeError(
                f"Cost optimization not proven optimal: {solver.status_name(status)}"
            )
        bestcost = sum(solver.value(v) for v in costs)
        model.add(sum(costs) == bestcost)
        model.maximize(sum(scores))
        solver.parameters.max_time_in_seconds = solver_seconds()
        status = solver.solve(model)
        if status != cp_model.OPTIMAL:
            raise RuntimeError("Service tie-break not proven optimal")
        totals = []
        for vs in allvars:
            totals += [solver.value(vs[i]) for i in range(0, len(vs) - 2, 4)]
        return self.evaluate(tuple(totals)) | {
            "solver_status": "OPTIMAL",
            "tolerance": tolerance,
            "objective_cost_mills": bestcost,
            "minimum_staffing_shortfall": self.min_deficit,
        }

    def evaluate(self, totals):
        rows = self.rows
        output = []
        pair = canonical(rows[:2], totals[:2])
        rx = canonical(rows[2:], totals[2:])
        if pair is None or rx is None:
            return None
        parts = pair[0] + rx[0]
        for r, n, (reg, flex, ot) in zip(rows, totals, parts):
            cost = r.paid_hours * (
                (reg + flex) * r.loaded_regular_hourly_cost
                + ot * r.loaded_overtime_hourly_cost
            )
            p = float(self.probs[int(r.dept_id)][n])
            low = (
                float(
                    self.service.probability(r.dept_id, r.demand_high, n, r.paid_hours)
                )
                if r.is_open
                else None
            )
            high = (
                float(
                    self.service.probability(r.dept_id, r.demand_low, n, r.paid_hours)
                )
                if r.is_open
                else None
            )
            output.append(
                dict(
                    dept_id=int(r.dept_id),
                    department=DEPTS[int(r.dept_id)],
                    employees=n,
                    regular=reg,
                    flex=flex,
                    overtime=ot,
                    cost=cost,
                    probability=p if r.is_open else None,
                    probability_stress_low=low,
                    probability_stress_high=high,
                    is_open=bool(r.is_open),
                    minimum=int(r.min_staff),
                    minimum_shortfall=max(int(r.min_staff) - n, 0) if r.is_open else 0,
                    utilization=(
                        float(
                            r.demand
                            * self.service.standards[int(r.dept_id)]
                            / (n * r.paid_hours)
                        )
                        if n * r.paid_hours
                        else None
                    ),
                    demand=float(r.demand),
                    demand_low=float(r.demand_low),
                    demand_high=float(r.demand_high),
                    available_regular=int(r.available_regular_employees),
                    flex_cap=int(r.cross_trained_flex_employees),
                    overtime_cap=int(r.max_overtime_employees),
                    draft_employees=int(r.draft_scheduled_employees),
                    availability_note=(
                        None
                        if str(r.availability_note) == "nan"
                        else r.availability_note
                    ),
                )
            )
        return {
            "allocations": output,
            "cost": sum(r["cost"] for r in output),
            "service": sum(r["probability"] or 0 for r in output)
            / max(1, self.open_count),
        }

    def certificate(self, plan):
        constraints = []
        totals = tuple(a["employees"] for a in plan["allocations"])
        for i, (r, a) in enumerate(zip(self.rows, plan["allocations"])):
            table = self.tables[0 if i < 2 else 1]
            idx = i if i < 2 else 0
            max_n = max(c.totals[idx] for c in table)
            best_p = float(self.probs[int(r.dept_id)][max_n]) if r.is_open else None
            lent = plan["allocations"][1 - i]["flex"] if i < 2 else 0
            active = []
            if a["regular"] + lent == r.available_regular_employees and r.is_open:
                active.append("Regular pool fully committed (including loans)")
            if a["overtime"] == r.max_overtime_employees and r.is_open:
                active.append("Overtime cap binding")
            if (
                a["flex"] == r.cross_trained_flex_employees
                and r.cross_trained_flex_employees
            ):
                active.append("Cross-training cap binding")
            if a["minimum_shortfall"]:
                active.append("Minimum staffing impossible with available workforce")
            if r.is_open and best_p < 0.95:
                active.append(
                    "95% modeled service objective unreachable with this pool"
                )
            constraints.append(
                dict(
                    dept_id=int(r.dept_id),
                    active=active,
                    max_employees=max_n,
                    standalone_max_probability=best_p,
                    probability=a["probability"],
                    minimum_shortfall=a["minimum_shortfall"],
                    regular_unused=int(
                        r.available_regular_employees - a["regular"] - lent
                    ),
                )
            )
        return {
            "status": "FEASIBLE" if not self.min_deficit else "MINIMUM_CONFLICT",
            "minimum_shortfall": self.min_deficit,
            "maximum_joint_service": self.max_score / SCALE / max(1, self.open_count),
            "constraints": constraints,
            "qualification": "Only Front End ↔ Merchandising share regular employees; Pharmacy remains licensed-only.",
            "interpretation": "Standalone maxima compete for the same partner pools and are not jointly attainable in general. 95% is an analyst diagnostic, not a guarantee.",
            "actions": [
                "Redistribute only qualified unused partner staff",
                "Seek additional qualified capacity if service risk is unacceptable",
                "Manage queues and defer noncritical replenishment during shortages",
            ],
        }

    def frontier(self):
        plans = [self.solve(t) for t in [0.0, 0.01, 0.02, 0.04, 0.06, 0.10, 0.15, 0.25]]
        keep = []
        for p in plans:
            if any(
                q["cost"] <= p["cost"] + 1e-6
                and q["service"] >= p["service"] - 1e-10
                and (
                    q["cost"] < p["cost"] - 1e-6 or q["service"] > p["service"] + 1e-10
                )
                for q in plans
            ):
                continue
            if not any(
                abs(q["cost"] - p["cost"]) < 1e-6
                and abs(q["service"] - p["service"]) < 1e-10
                for q in keep
            ):
                keep.append(p)
        return sorted(keep, key=lambda p: p["cost"])

    def last_worker(self, plan):
        totals = tuple(a["employees"] for a in plan["allocations"])
        options = []
        for recipient in range(3):
            if not self.rows[recipient].is_open:
                continue
            for donor in [None] + ([1 - recipient] if recipient < 2 else []):
                new = list(totals)
                new[recipient] += 1
                if donor is not None:
                    new[donor] -= 1
                if any(
                    n < 0
                    or n >= len(self.probs[int(r.dept_id)])
                    or (r.is_open and n < r.min_staff)
                    for n, r in zip(new, self.rows)
                ):
                    continue
                alt = self.evaluate(tuple(new))
                if alt is None:
                    continue
                # Evaluation uses the same canonical availability conservation as the optimization tables.
                gain = sum(
                    (a["probability"] or 0) - (b["probability"] or 0)
                    for a, b in zip(alt["allocations"], plan["allocations"])
                )
                options.append(
                    {
                        "recipient": int(self.rows[recipient].dept_id),
                        "donor": (
                            int(self.rows[donor].dept_id) if donor is not None else None
                        ),
                        "kind": (
                            "Transfer"
                            if donor is not None
                            else "Unused eligible capacity"
                        ),
                        "net_expected_targets_gain": gain,
                        "incremental_cost": alt["cost"] - plan["cost"],
                        "recipient_gain": alt["allocations"][recipient]["probability"]
                        - plan["allocations"][recipient]["probability"],
                        "donor_effect": (
                            alt["allocations"][donor]["probability"]
                            - plan["allocations"][donor]["probability"]
                            if donor is not None
                            else 0.0
                        ),
                        "allocations": alt["allocations"],
                    }
                )
        if not options:
            return {
                "recommendation": None,
                "alternatives": [],
                "reason": "No eligible single-worker addition or partner transfer preserves staffing minimums and capacity.",
            }
        model = cp_model.CpModel()
        idx = model.new_int_var(0, len(options) - 1, "last_worker_choice")
        gain = model.new_int_var(-3 * SCALE, 3 * SCALE, "net_service_gain")
        model.add_element(
            idx, [round(o["net_expected_targets_gain"] * SCALE) for o in options], gain
        )
        model.maximize(gain)
        solver = cp_model.CpSolver()
        solver.parameters.num_search_workers = 1
        solver.parameters.max_time_in_seconds = solver_seconds()
        if solver.solve(model) != cp_model.OPTIMAL:
            raise RuntimeError("Last Worker service solve not optimal")
        bestgain = solver.value(gain)
        model.add(gain == bestgain)
        cost = model.new_int_var(-10000000, 10000000, "incremental_cost_mills")
        model.add_element(
            idx, [round(o["incremental_cost"] * 1000) for o in options], cost
        )
        model.minimize(cost)
        solver.parameters.max_time_in_seconds = solver_seconds()
        if solver.solve(model) != cp_model.OPTIMAL:
            raise RuntimeError("Last Worker cost solve not optimal")
        best = options[solver.value(idx)]
        positive = best["net_expected_targets_gain"] > 1 / SCALE
        return {
            "recommendation": best if positive else None,
            "alternatives": sorted(
                options,
                key=lambda x: (-x["net_expected_targets_gain"], x["incremental_cost"]),
            ),
            "reason": (
                "Highest net modeled service benefit after lender opportunity cost; cost breaks ties."
                if positive
                else "No one-worker change improves net modeled service at the solver precision. Retain this allocation."
            ),
        }
