# SHIFTWISE
### Workforce Resilience Command Center

A working React/TypeScript + Python decision-support application for the **Texas MISA Fall 2026 Costco Workforce Planning Case**. FORGE: Forecast demand, Optimize staffing, Reallocate resources, Guard service, Evaluate outcomes.

**All inputs are simulated competition data. Costs, forecasts and service probabilities are projections, not actual Costco results.**

## Launch

Prerequisites: Python **3.12**, Node **20.19+ or 22.12+**, npm, Linux/macOS. The tested environment uses Python 3.12 and Node 24. No SQL Server, API keys, external services or manual coding is required.

```bash
cd /workspace/casecomp
./scripts/install.sh
./scripts/start.sh
```

On an already prepared environment, run only `./scripts/start.sh`. It serves the production dashboard and API on port **8000**. Open that port in your local browser/port-forwarding client. Initialization audits sources, trains models and solves all official groups; allow roughly 20–60 seconds. `PORT=8080 ./scripts/start.sh` chooses another port. API readiness: `curl --fail http://127.0.0.1:8000/api/health`.

For hot-reload development:

```bash
./scripts/dev.sh
```

This starts the backend on 8000 and Vite on 5173; Vite proxies `/api`. Stop with Ctrl+C. Each cloud task is already isolated; use this checkout rather than creating a worktree.

## What works

- **Command Center:** official weekly scenario comparisons and selected block staffing/cost/service.
- **Demand Intelligence:** time-ordered candidate comparison, warehouse/department WAPE, reconciled forecasts, benchmark comparison, uncertainty stresses and held-out service calibration.
- **Staffing Optimizer:** genuine CP-SAT joint FE/MS optimization, licensed-only Pharmacy, regular/flex/overtime and source-defined costs; three explicit service-loss tolerances.
- **Scenario Lab:** official BASE/PEAK/DISRUPT and live demand/availability/sensitivity controls that rerun optimization. Availability cannot create extra employees.
- **Decision & Export:** Last Worker with lender opportunity cost, independent Feasibility Certificate, inspectable nondominated frontier, deterministic explanations and validated 567-row CSV.

The official download always uses **Service First with official source scenarios**. Custom simulations and mode changes do not overwrite it. Team ID is configurable in the UI and export script.

## Test and generate outputs

```bash
./scripts/test.sh                      # backend/solver/API tests + TypeScript/production build
./scripts/export.sh --team-id SHIFTWISE
.venv/bin/python -m scripts.validate_submission
```

The standalone validator imports no solver and reads the original source grid/template. Useful outputs:

| Output | Evidence |
|---|---|
| `artifacts/TEAM_SUBMISSION_COMPLETED.csv` | All 567 rows, exact original columns/metadata/order, integer assignments |
| `artifacts/validation_report.json` | Independent submission feasibility/cost audit |
| `artifacts/data_audit.json`, `data_audit.md` | Source checks, row counts, original CSV hashes, workbook parity |
| `artifacts/forecast_evaluation.csv`, `forecast_backtests.csv` | Past-only fold predictions and nine group metrics per method |
| `artifacts/forecast_planning_week.csv`, `forecast_vs_benchmark.csv` | Daily/shift reconciliation, exact multipliers, stress bounds |
| `artifacts/optimized_allocations.csv`, `plan_vs_draft.csv` | Solver decisions and hypothetical draft comparisons |
| `artifacts/scenario_summary.csv`, `feasibility_certificates.json` | Computed service/cost/risk and binding source constraints |
| `artifacts/model_metrics.json`, `service_calibration.png` | Time-held-out service metrics and forecast selection |
| `artifacts/presentation_evidence.json` | Verified model outputs and data-selected demonstration |
| `artifacts/test_results.xml`, `browser_test_results.json` | Actual automated test results |
| `artifacts/screenshots/` | Screenshots captured from the running application |

Optional real-browser verification and snapshot generation (server must be running):

```bash
.venv/bin/python -m pip install -r backend/requirements-browser.txt
# Requires Chromium; set CHROMIUM_PATH to its executable if not /usr/bin/chromium.
.venv/bin/python scripts/browser_smoke.py
```

In the managed execution environment, local socket/network commands may require the provided execution-tool sandbox escalation. Preserve the configured proxy and TLS verification for dependency installation; no external font or model service is used.

## Architecture and methodology

`backend/`: source audit, forecasting, monotone service models, finite-domain integer optimization, independent verifier and FastAPI. `frontend/`: React/TypeScript/Vite/Recharts dashboard. `scripts/`: installation/start/test/export/browser automation. `tests/`: meaningful source, forecast, solver, constraint, export and API tests. `data/raw/`: untouched source copies. Original root competition inputs remain intact; [original README](docs/ORIGINAL_README.md) describes the competition bundle.

Read [methodology](docs/METHODOLOGY.md), [decision logic](docs/DECISION_LOGIC.md), [assumptions and limitations](docs/ASSUMPTIONS_AND_LIMITATIONS.md), [demo script](docs/DEMO_SCRIPT.md), and [judge Q&A](docs/JUDGE_QA.md). See `STRATEGY.md` and `01_CODEX_MASTER_BUILD.md` for requirements.

The forecast benchmark is not claimed to be beaten. Holiday sample support is limited; uncertainty envelopes are stress ranges rather than confidence intervals. Optimality applies to the finite aggregate model, not a named individual roster or guaranteed service. Closed blocks are excluded from attainment averages. Workload units are never pooled across departments. The Last Worker can honestly recommend no move.

Prompts **1 and 2** are implemented. See [independent audit](artifacts/INDEPENDENT_AUDIT.md) and [verified presentation claims](artifacts/verified_presentation_claims.csv). Prompt 3 polish and local acceptance are complete; no deployment has been performed.

## Presentation-ready local demo (Prompt 3)

After `./scripts/install.sh`, run `./scripts/demo.sh`. It starts the production app on port 8000, checks readiness, and computes the four distinct guide selections into the process-local cache. Use `PORT=8001 ./scripts/demo.sh` if port 8000 is already in use. Stop the launcher with Ctrl+C. To check an already running app, use `./scripts/smoke.sh` (set PORT if needed). To run without warming, `./scripts/start.sh` remains available.

Click **Start guided demo** for five large-format, resettable scenes: BASE → PEAK → DISRUPT → Last Worker → Decide & Export. The Last Worker step uses the audited Balanced example and shows the rejected transfer's lender loss alongside the recommended addition. Exit presentation restores the full interactive workspace. Solver errors hide stale recommendations and show clearly labeled official week reference totals.

The timed click-by-click script is [artifacts/demo_run_of_show.md](artifacts/demo_run_of_show.md), with 3-minute and 4-minute versions and an optional 5-minute discussion. [artifacts/DEMO_ASSETS](artifacts/DEMO_ASSETS) contains seven real application screenshots, PNG/SVG charts, a FORGE diagram and JSON live evidence. Recreate them against a running local app with `MPLCONFIGDIR=/tmp/shiftwise-mpl python scripts/presentation_assets.py` using the optional Playwright dependency and Chromium.

**Offline after installation:** runtime has no external model, font, data or cloud-service dependency. Automated Python tests forbid network connections during complete model generation. Browser rehearsal blocks every external hostname while the local API, five scenes and CSV download remain functional. Installation still needs package registries; the live demo still needs the local server running. Backup screenshots are captured results, never a substitute passed off as a live calculation.

Deployment has **not** been performed. Before external deployment, decide authentication/authorization, HTTPS and access routing, concurrency and persistence requirements, monitoring, and production-data calibration. The independent audit's conditional model limitations remain in force.
