# PROMPT 1: BUILD THE COMPLETE SHIFTWISE APPLICATION

You are the lead software engineer, operations research scientist, data scientist, and product designer for a Texas MISA Fall 2026 case competition submission sponsored by CGI. Build a complete, professional, data-driven application called SHIFTWISE: Workforce Resilience Command Center. Implement the solution in this repository, run it, test it, and produce finished artifacts. I do not want to personally write code. Do not stop at a plan, static mockup, or architecture document. Take the task through a working application and exportable competition submission.

## 1. Mandatory source inspection
First list and inspect all supplied files, including the ZIP if attached. Extract `SHIFTWISE_CASE_INPUTS.zip` if necessary. Prioritize the original case PDF, `docs/README.md`, `docs/ASSUMPTIONS.md`, `docs/DATA_DICTIONARY.md`, `csv/v_ShiftHistory.csv`, `csv/v_PlanningWeekGrid.csv`, `csv/TEAM_SUBMISSION_TEMPLATE.csv`, `csv/PlanningWeek_BenchmarkForecast.csv`, `csv/comp_*.csv`, and the provided Excel workbook. SQL scripts are optional reference and validation material, not a reason to require SQL Server.

The case dataset is simulated, not actual Costco information. Historical period: January 1 to February 11, 2026. Planning period: February 12 to 18, 2026. Stores: 1, 2, 4. Departments: 38 Front End, 92 Merchandising, 95 Pharmacy. Shifts: OPEN, MID, EVE. Scenarios: BASE, PEAK, DISRUPT. The original CSV template has exactly 567 rows and must be preserved column for column, except for populated submission values and a configurable team ID. The client must never present synthetic data or projections as observed real-world Costco results.

If the exploratory file `MISA_Strategy_Research_Bundle.zip` is attached, use it only as a research reference. Its logistic calibration, heuristic policies, cost estimates, 10 infeasible draft shift groups, and demonstrations are preliminary and MUST be independently verified. Do not use those numbers as ground-truth labels or hardcode them as outputs. The competition source files outrank all prior chat analysis.

## 2. Definition of success
A warehouse manager must be able to: select a warehouse, date, shift, department, and scenario; compare current draft vs optimized staffing; view regular, overtime and cross-trained allocation; see predicted workload, customer-service risk, labor cost, and limiting constraints; alter plausible scenario parameters; click Recalculate and receive a new valid recommendation; inspect why it changed; ask where one additional qualified worker would create the most net service value; view a cost-service frontier; and export the 567-row competition submission.

Build a REAL working application, not a screenshot collection. Every displayed numerical value must come from supplied data, an explicitly documented modeling assumption, or executed calculations. No fake counters, canned model decisions, prewritten scenario numbers, arbitrary ROI, or fabricated confidence intervals. Reference screenshots may be generated FROM the running app, not invented as proof of functionality.

## 3. Project engineering setup
Create a maintainable monorepo, preferably `frontend/` (React, TypeScript, Vite, Tailwind, Recharts), `backend/` (Python, FastAPI, Pydantic, pandas, numpy, scikit-learn, OR-Tools CP-SAT or a justified equivalent), `data/raw/`, `artifacts/`, `tests/`, `docs/`, `scripts/`. Use minimal dependable dependencies. If the environment constrains a technology, adapt while preserving the actual capabilities and explain why.

Create `AGENTS.md` with durable project rules, `PROJECT_PLAN.md` with milestones and checkable acceptance criteria, and `docs/ASSUMPTIONS_AND_LIMITATIONS.md` differentiating dataset facts, forecast assumptions, estimates, and unknowns. Keep untouched copies of original source inputs. Do not overwrite source CSVs. Build scripts to install, start backend and frontend, test, export results, and produce a demonstration snapshot. Provide a polished README with exact run commands. Work autonomously through the milestones and repair errors before declaring completion.

## 4. Audit and forecasting engine
Validate data types, duplicate keys, expected row counts, closed blocks, scenario mappings, shift durations, minimum staffing, missing labels, training versus planning dates, and correspondence with the submission template. Write validation results to `artifacts/data_audit.json` and a human-readable report.

Implement a time-aware forecast evaluation pipeline comparing at least a 2-, 3-, and 4-week same-weekday moving average, the provided benchmark, and one appropriately regularized or tree-based model if data supports it. Use rolling backtests with strictly past data and report WAPE/MAE by warehouse and department, not only overall. Detect insufficient support for a complex model. Select the forecasting approach based on evidence rather than an instruction to use ML.

Create planning-week daily forecasts, supported holiday-window adjustments with documented shrinkage and uncertainty, and shift shares that reconcile to daily predictions. Avoid target leakage. Apply the exact `demand_multiplier` values from the official planning grid to PEAK; DISRUPT keeps the BASE workload while availability changes. Closed shifts receive zero workload and zero headcount. Make the forecasts reproducible with fixed random seeds and exported forecast CSVs.

## 5. Service model
Use only historical actual workload, worked headcount/hours, and available explanatory fields to estimate department-specific service target attainment and, if defensible, approximate wait-time/replenishment outcomes. Utilization = demand_units * labor_hours_per_workload_unit / (headcount * paid_hours). Use each department's actual target and distinct workload standard. Never sum demand units across departments as if they were comparable.

Fit an interpretable statistical model with time-ordered evaluation, probability calibration checks, sample sizes, Brier score and AUC when defined, and bounded outputs. Include warehouse adjustments only when validated. The synthetic service generation may induce an unusually sharp threshold, so avoid unjustified certainty. Label outputs as MODEL ESTIMATES, not guaranteed outcomes. Include a transparent fallback monotone service curve if a fitted model fails validation; document the fallback rather than masking it. Export service-model metrics and diagnostic charts.

## 6. Joint staffing optimizer, the nonnegotiable centerpiece
Implement an actual integer optimization model for each warehouse-date-shift group, jointly optimizing Front End and Merchandising and separately respecting Pharmacy's qualified-only pool. Decision variables must distinguish total assigned headcount, local regular staff, regular-rate cross-trained borrowable staff, and overtime staff. Observe the provided availability/capacity definitions, no double-counting of cross-trained people, minimum-staff floors on open shifts, zero on closed shifts, and scenario-specific reductions. Borrowing workers must reduce the lender's available pool within that same shift. Model aggregate availability only; do not claim to have built a named individual roster or verified individual hours beyond the dataset.

Match the official cost convention: eligible regular employees first, eligible cross-trained staff second, overtime last. Loaded hourly cost and paid hours must come from source data. Use the competition's stated service-first objective, with cost efficiency secondary, while enforcing hard feasibility. Provide three clearly distinguished operating modes such as Service First, Balanced, and Budget Conscious, with transparent tolerances or budget constraints. A multi-objective frontier is preferred over a single arbitrary weighted score. If service objectives cannot be satisfied with available workers, return a mathematically feasible best-effort schedule and clearly report the unmet service objective. If even minimum staffing is infeasible, show the source constraint conflict and NEVER silently invent workers. Do not claim the service target is met merely because all available workers were scheduled.

Implement an independent feasibility verifier not dependent on trusting the solver output. Recalculate cost from allocations and compare with the benchmark/draft. The draft itself may be infeasible under DISRUPT; explicitly label any hypothetical draft cost/service projection as non-executable.

## 7. Signature decision features
A. `The Last Worker`: for the currently selected warehouse-date-shift, evaluate the net effect of moving or adding ONE actually eligible worker across feasible allocations. Compute marginal service benefit, labor cost, and impact on the department providing the worker; account for opportunity cost. If no such transfer is feasible, say why. Do not hardcode a particular date or dramatic delta.
B. `Feasibility Certificate`: display the active constraints, binding shortages, maximum achievable service under model assumptions, and action categories requiring extra capacity when applicable. Distinguish a feasible schedule with service risk from an infeasible headcount schedule.
C. `Service Frontier`: interactive comparison of multiple nondominated staffing plans, cost against modeled service outcomes, and what changes under varying forecast uncertainty.
D. `Explain My Decision`: deterministic, traceable explanation constructed from computed deltas and constraints. An LLM may optionally paraphrase, but may not control the optimization or invent facts.

## 8. Interface and demo
Build a polished, fast desktop-friendly executive interface, not a generic CRUD dashboard. Screens or tabs:
1) Command Center: total projected labor cost, service-target attainment, coverage alerts, scenario comparison, warehouse selector.
2) Demand Intelligence: historical profiles, selected forecast, time-aware validation, uncertainty and calendar effects.
3) Staffing Optimizer: draft vs recommendation, department-by-shift staffing, regular/flex/overtime breakdown, cost-service slider or modes, feasibility.
4) Scenario Lab: BASE/PEAK/DISRUPT toggle, demand/availability controls, Recalculate, decision log and transparent risk warnings.
5) Decision & Export: Last Worker, Feasibility Certificate, frontier, downloadable staffing submission, assumptions and appendix evidence.

Use a restrained professional enterprise aesthetic, readable labels and numbers, accessible color contrasts, clean data visualization, responsive loading/error states, and clear icons for statuses. Make the scenario demo useful immediately after launching the app with a guided tour, but the tour must invoke real computations. Seed the interface from the official case data, never fabricated values.

Recommended demonstration: Warehouse 2 on February 14 at MID shift to compare BASE/PEAK/DISRUPT, followed by Warehouse 2 on February 13 at OPEN for a potential cross-trained marginal-worker transfer. First compute and validate these examples. If they do not produce the strongest defensible live demonstration, programmatically select and document an alternative from actual calculated outputs.

## 9. Outputs to generate
- A working frontend and backend with explicit start scripts.
- Tests for data audit, forecast reproducibility, scenario multipliers, daily/shift reconciliation, closed shifts, minimum headcount, no flex double-counting, overtime caps, pharmacy restrictions, cost formula and solver feasibility.
- `artifacts/TEAM_SUBMISSION_COMPLETED.csv` with EXACT same rows and columns as the template, nonnegative integer `submitted_employees` for all 567 rows, 0 for closed blocks, configurable team ID. Never call a file final if it fails validation.
- `artifacts/forecast_evaluation.csv`, `artifacts/forecast_planning_week.csv`, `artifacts/optimized_allocations.csv`, `artifacts/plan_vs_draft.csv`, `artifacts/scenario_summary.csv`, `artifacts/model_metrics.json`, `artifacts/validation_report.json`, `artifacts/presentation_evidence.json`.
- `docs/METHODOLOGY.md`, `docs/DECISION_LOGIC.md`, `docs/ASSUMPTIONS_AND_LIMITATIONS.md`, `docs/DEMO_SCRIPT.md`, `docs/JUDGE_QA.md`.
- Screenshots generated from the running application and, optionally, a short screen capture if this environment allows it.

## 10. Final acceptance gates
Run the full application. Run automated tests, build the production frontend, exercise live scenario controls, export the CSV, and independently audit all 567 rows. Cross-check key calculations against source tables and independently computed test fixtures. No unhandled exceptions, fake functionality, placeholder charts, or unavailable files. Provide exact run commands, links or paths to deliverables, a list of tests actually executed with results, and any unresolved limitations. If tooling is unavailable, preserve a working reduced implementation and report the blocker transparently rather than claiming a feature works.

Do not ask me to handwrite code or perform normal implementation subtasks. Make reasonable technical decisions and implement, validate, and document them. Start by inspecting the files and continue through working deliverables.
