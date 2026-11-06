> Historical Prompt 1 record at commit 9c66981. Superseded costs, coverage objective and precision are corrected in [the independent audit](../artifacts/INDEPENDENT_AUDIT.md). Do not use this historical report as current presentation evidence.

# Prompt 1 build acceptance

Completed on task branch `work`. Prompts 2 and 3 were not executed.

## Delivered

Five-screen React/TypeScript production dashboard, FastAPI backend, immutable case inputs, audited forecasts and service models, explicit integer CP-SAT staffing, independent verifier, official and custom scenarios, Last Worker, Feasibility Certificate, inspectable frontier, exact-template CSV download, test automation, startup/install/export scripts, screenshots and methodology/assumptions/demo/judge documentation.

## Executed checks

- `scripts/install.sh`: succeeded using a standalone Python virtual environment, complete Python lockfile and npm frozen dependency installation. `pip check`: no broken requirements.
- `scripts/test.sh`: **30 passed**, zero failed. Covers source audit, past-only forecast origins and reproducibility, macro WAPE, daily reconciliation across scenarios, exact multipliers, closures, monotone service predictions, independent staffing/cost checks, no double counting, Pharmacy restrictions, overtime, safety conflicts, low-probability coverage safeguard, exhaustive small-model optimum, frontier and marginal decisions, API validation and CSV mutation rejection.
- TypeScript check and Vite production build: succeeded. One non-failing Starlette test-client deprecation warning remains in the Python suite.
- Real Chromium browser: all five screens, solver mode changes, BASE/PEAK/DISRUPT, real slider-driven recalculation, expected reduced-availability Pharmacy minimum conflict, marginal decisions, frontier inspection, exact 567-row download, guided tour and mobile layout. No JavaScript page exceptions. Results in `artifacts/browser_test_results.json`; seven actual application screenshots and `demonstration_snapshot.json` are retained.
- `scripts/export.sh`: generated every required analytical artifact and official staffing CSV.
- `.venv/bin/python -m scripts.validate_submission`: **valid**, 567 rows, no errors. Exact columns, metadata/order, complete keys, integer employees, closed zeros, staffing minimums, shared-pool conservation and cost recalculation checked independently of the solver.
- Source audit: **94 passed** checks, including all workbook data sheets matching supplied CSVs. Original inputs preserved.

The final export contains 567 OPTIMAL aggregate-model allocation rows. Summed scenario cost is $997,870.925 before display rounding, recomputed from source hours/rates. Half-cent amounts from half-hour shifts are retained rather than silently rounded per row. This is not a realized spending result.

Forecast selection uses macro WAPE across nine warehouse/department groups: four-week same-weekday mean, **3.75025%** on two weekly-origin folds. It does not establish an improvement over the supplied planning benchmark. Historical service-target attainment independently reproduces 76.9648% FE, 69.9187% Merchandising and 88.2540% Pharmacy. The original draft is infeasible in 10 distinct DISRUPT warehouse/date/shift groups; every submitted recommendation passes the independent capacity/minimum checks.

The official Last Worker browser snapshot (Warehouse 2, Feb 13, OPEN, DISRUPT, Balanced) computes an unused-eligible-capacity addition to Merchandising: approximately 5.1394 percentage points recipient gain at $187.20 incremental block cost. A proposed FE-to-Merchandising transfer has negative net modeled value after the lender effect. These values are executed model estimates, not hardcoded demonstration outputs or causal claims. The snapshot records all alternatives.

## Scope and remaining limits

No required Prompt 1 installation, application, model, export or acceptance check remains blocked. This is a competition proof of concept with aggregate staffing, short simulated history, neutral central holiday effects when unsupported, sensitivity envelopes rather than confidence intervals and no validated minute-level/causal model or individual roster. See `ASSUMPTIONS_AND_LIMITATIONS.md`.

The production app was started and restarted successfully on port 8000. Runtime processes are not retained by cloud snapshots. Complete `install_script` and `start_skill` were saved to the environment configuration draft. Saving does not publish; review/save in environment settings and publish if you want the prepared snapshot reused. Publication and fresh-task restoration were not claimed or tested.

## Launch and regenerate

From `/workspace/casecomp`, use `./scripts/start.sh` (prepared instance) or first run `./scripts/install.sh` (fresh checkout). `scripts/dev.sh` starts Vite and backend hot reload. `scripts/export.sh --team-id YOUR_TEAM` regenerates the official Service First submission. The application download validates the team ID and all rows before returning it. Custom simulation controls never alter the official export.
