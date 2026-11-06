# SHIFTWISE independent audit — Prompt 2

**Decision: CONDITIONAL PASS for the simulated competition proof of concept.**

Audited baseline: commit `9c66981`, task branch `work`. Prompt 3 was not read as an execution instruction or executed. All known reproducible software defects identified below are repaired. Conditions concern interpretation of the short simulated history and use of corrected evidence, not an unreported failing test. This audit is a separate skeptical review process in the same agent session, not third-party organizational assurance.

## 1. Review scope and independence

Read the strategy, Prompt 2, original case PDF (fresh extraction matches `docs/CASE_EXTRACTED.txt` byte-for-byte), original README, assumptions, data dictionary, template, all source CSVs/workbook sheets and application modules. Compared source copies, row counts, dates and workbook parity using the current 94-check source audit. Root competition input CSVs, PDF, workbook and strategy are unchanged.

Reviewed the forecasting, service, optimizer, verifier, API, React state/rendering, startup/export scripts, prior tests and artifacts. Do **not** infer correctness from the original 30 tests: they passed while missing a significant objective error.

New `scripts/audit_independent.py` reads **root original inputs**, not the application's raw-data reader. It does not import production `canonical`, `verify_totals`, `validate_submission`, or forecast functions. It constructs the full Cartesian headcount domain independently, calculates regular/flex/overtime using source pools, filters feasibility and minimum conflicts, and evaluates direct logistic/interpolated isotonic mathematics instead of calling production probability inference. Model parameters are necessarily shared for evaluating the same stated objective; independent refit tests separately challenge their historical validation.

It evaluated **342,687 source-feasible, minimum-shortfall-minimizing triples across all 189 official warehouse/date/shift/scenario groups**, not randomized simulations. Selected-group frontier and marginal decisions are also checked against the complete feasible domain. Tests use source-derived adversarial fixtures; their edited capacities are test cases, never exported as competition employees.

Reproduction:

```bash
./scripts/test.sh
./scripts/export.sh --team-id SHIFTWISE
MPLCONFIGDIR=/tmp/shiftwise-mpl .venv/bin/python -m scripts.audit_independent
# Start the audited app; port 8001 was used to avoid the old server during comparison.
PORT=8001 ./scripts/start.sh
python scripts/browser_smoke.py --url http://127.0.0.1:8001
python scripts/audit_browser_failure.py
.venv/bin/python -m scripts.audit_claims
.venv/bin/python -m scripts.validate_submission
```

Browser scripts require the optional Playwright dependency and Chromium, as documented in README. API tests/browser require local socket access in this managed environment; execution sandbox escalation was used. No TLS/signature verification was disabled.

## 2. Findings and repairs

| ID / severity | Reproducible evidence in baseline | Repair and regression evidence |
|---|---|---|
| A1 **HIGH** — dominated spending / objective mismatch | Exhaustive enumeration finds **9** official DISRUPT groups with cheaper staffing and exactly equal modeled service. Example: W2 / Feb 13 / EVE has **$1,990.16** excess modeled cost. Baseline's workload-coverage radix made coverage precede cost, contradicting service-first/cost-second. Total avoidable projected cost **$15,573.23** across these groups. | Removed coverage from the service floor. CP-SAT now minimizes cost subject to maximum service minus explicit tolerance, then maximizes service at tied cost. Increased score resolution from 0.0001 to 0.000001. `audit_exhaustive_groups.csv` retains old/new comparisons: **0 dominated corrected groups**, **0 true service-score gap** on all official inputs. The low-probability plateau regression now challenges overspending rather than requiring it. |
| A2 **MEDIUM** — positive service with no capacity | `Service.probability(dept, positive demand, 0, hours)` returned 0.005 because division default and clipping treated an empty shift as an ordinary extrapolation. | Zero productive capacity now has probability **0**. Tests require zero-workforce plans to contain zero workers and zero probability; no invented workers. Nonempty staffing remains bounded to 0.005–0.995. |
| A3 **MEDIUM** — calibration bins overlap | In baseline `metrics`, a probability exactly 0.2 belongs to both neighboring bins because of an added epsilon; bin totals can exceed the sample count and ECE is wrong. | A unique integer bin index partitions [0,1], with 1 assigned to the final bin. Regression uses 0, 0.2, 0.4, 0.6, 0.8 and 1, checks sample conservation and independent Brier arithmetic. Current historical probabilities did not fall at problematic boundaries; reported historical scores remain consistent. |
| A4 **MEDIUM** — stale decision after API failure | React retained the previous decision under newly changed controls when a request failed; loading ended and stale results became visible again. | Hide decision panels on error, retain error/retry UI. Real Chromium injects HTTP 503, confirms no decision panel remains, removes interception, retries and verifies fresh results. `audit_browser_failure.json`. |
| A5 **LOW** — oversized counts can overflow | Counts such as 1e30 satisfy finite/nonnegative/integer checks but overflow int64 conversion. | Reject values outside safe integer bounds before conversion. Adversarial tests also corrupt scenario identity, closure/minimum metadata and draft counts; invalid files fail closed. |
| A6 **LOW** — unchecked marginal solver outcomes | Last Worker read variable values without checking either CP-SAT solve status. | Both service selection and cost tie-break require OPTIMAL or return an explicit error. Gain-variable bounds now derive from the common score precision. |

## 3. Data, submission and worker conservation

The exact template has **567** rows, 13 columns, three scenarios, warehouses 1/2/4, departments 38/92/95, seven dates and OPEN/MID/EVE blocks. Independent oracle checks original column order and all fixed metadata in original row order; integer counts, closed zeros, minimums, duplicate keys and complete matching keys are checked. A separate production validator remains in place; independent tests mutate valid output rather than trusting it.

For each receiving block, the oracle reconstructs local regular staff, then incoming flex bounded by receiving qualification cap **and** unused partner regular pool, then overtime. Pharmacy cannot borrow. The opportunity cost is real: lending consumes the same source pool, not an extra global resource. Both departments cannot borrow the same local worker or free a regular worker by paying their own replacement overtime under the official regular-first convention.

New exhaustive fixtures cover exactly one eligible partner worker, both departments seeking scarce flex, zero workforce, closed Pharmacy and W2 DISRUPT. All three operating tolerances are checked against independently enumerated minimum costs. Impossible minimums remain MINIMUM_CONFLICT; capacity can be valid while safety staffing is not.

All **567 corrected submission rows** pass. The actual **browser-downloaded** file is saved as `browser_download.csv`, read back through the separate oracle and passes too (`audit_browser_download.json`); its team ID is intentionally BROWSER_TEST. The official competition file remains `TEAM_SUBMISSION_COMPLETED.csv` with team SHIFTWISE.

## 4. Labor cost and draft consistency

Original source assumptions define loaded regular = base × (1 + 0.25), loaded OT = base × 1.5 × (1 + 0.10), using supplied rounded loaded rates. There is no repeated benefits burden. Each department uses its own receiving rate and paid hours; hours vary by shift/day type. `audit_decimal_cost_trace.csv` recomputes every allocation with Decimal, then tests compare it with production traces. Half-cent amounts are retained; solver cost precision is $0.001.

Corrected scenario projected costs:

| Scenario | Projected cost | Mean modeled attainment | Infeasible original draft groups |
|---|---:|---:|---:|
| BASE | $326,103.140 | 99.2049% | 0 |
| PEAK | $348,786.975 | 97.9638% | 0 |
| DISRUPT | $307,407.580 | 94.2549% | 10 |

The sum **$982,297.695** is a validation total across three **alternative scenario plans**, not a single realized week's spending. The nine corrected allocations reduce projected expense by $15,573.23 relative to baseline `9c66981`; this is not demonstrated business savings or evidence that cutting real staff is safe. Draft is recomputed using the same forecast/cost convention and marked hypothetical/non-executable wherever its capacity fails. The ten DISRUPT conflict groups independently reproduce.

## 5. Forecast audit

Independent arithmetic recomputes every 2/3/4-week weekday prediction from original `comp_FactShiftDemand.csv`, selecting positive historical daily totals strictly before each weekly origin. Independent dense weekday indicators and manually standardized holiday/promotion/temperature features reproduce ridge predictions within numerical solver tolerance. A poisoning test replaces holdout demand/worked staff/service labels with extreme values; ridge predictions do not change. MAE and WAPE are recomputed from exported predictions in `audit_forecast_metrics.csv`.

Both weekly origins forecast seven days without intraweek actual updates. The Jan 29 Thursday has only three positive earlier Thursdays for the four-week candidate because Jan 1 is closed: this is a reduced-support average, not four fabricated observations. Evaluation support is only two origins / 126 daily observations per method. Selection uses a macro average over nine warehouse/department WAPEs, never a mixed-unit total. Four-week weekday remains selected at **3.7502478% macro WAPE**; this is selection evidence, not an additional untouched forecast test.

The 63 planning daily forecasts match the supplied benchmark up to its four-decimal rounding (maximum difference **0.00005 units**). No benchmark-beating claim is warranted. BASE daily and shift demand reconcile; all three scenario daily forecasts equal shift sums. Every exact official demand multiplier is used; DISRUPT demand equals BASE while capacity changes. Closed blocks have zero demand. Historical mean shares are normalized by department/day type; no future actual share is used.

Calendar shrinkage is a candidate, not a validated holiday uplift. Central adjustment remains neutral because the selected model does not support a new holiday effect. Future actuals are unavailable. Sensitivity envelopes are department residual quantiles plus a disclosed holiday allowance, **not confidence intervals** or validated holiday coverage. Historic temperature is assumed available as planning context; the data does not supply vintage weather forecasts to independently establish real-world ex-ante availability. These limitations remain explicit.

## 6. Service predictions, calibration and uncertainty

Independent refits use actual worked hours, department-specific source labor standards and source labels. Fit through Jan 28 for the held-out Jan 29–Feb 11 assessment; final inference fits through Feb 11. Tests independently calculate Brier and rank-based AUC, and reconstruct final logistic probabilities / isotonic interpolation. Sample counts are 126 FE, 126 Merchandising, 108 Pharmacy test blocks. Original historical attainment independently reproduces approximately 76.96%, 69.92%, 88.25% respectively.

Held-out Brier values remain approximately 0.02410 / 0.01847 / 0.01891. These do not demonstrate causal effects or robustness outside the simulated utilization support. Probabilities can jump steeply, isotonic endpoints plateau, and rare calibration bins have very few failures. Zero staffing is now a physical zero-probability override. The lower bound on **nonzero** staffing can make all feasible employees appear to have equal low probability during severe shortages. The repaired optimizer must not invent marginal service benefits to justify spending: it returns the cost-efficient solution for that model and explicitly warns that extra capacity's real benefit is unvalidated. Certificate maxima/stress results expose the residual risk. Do not interpret such a recommendation as a validated operational permission to cut coverage.

## 7. Integer optimality, baselines, frontier and Last Worker

All official recommendations have zero independently measured true service gap to the best feasible triple; no lower-cost, equal-or-better-service allocation exists. CP-SAT requires OPTIMAL for both stages. Global optimality is for the **finite group model at 0.000001 score precision**, not for real service, named employees, or an unmodeled weekly business objective. A general quantization error of up to 0.0000005 per block remains possible; the exhaustive oracle found no true-score gap on these official inputs.

`audit_heuristic_baselines.csv` compares 78%, 82%, 90% utilization heuristics after independently choosing their nearest capacity-feasible repair (L1 headcount distance, cost tie-break). Service First is at least as good in modeled service in every group for all three baselines. Cost need not be lower because service is primary. The earlier 82% exploratory cost/headcount results are **not** reproduced or promoted as ground truth.

The selected DISRUPT frontier is challenged against the complete feasible domain, not just the eight plotted choices; no point is dominated. The displayed frontier is still a sampled set of nondominated alternatives, not every efficient allocation. Source-derived edge-case CP-SAT optima match the exhaustive oracle for each mode. Standalone departmental certificate maxima compete for shared pools and cannot be summed as a jointly feasible plan.

Last Worker options use net probability change including the lender and source-rate cost changes. The independent oracle checks all 189 official groups in Balanced mode: all 877 returned options match the complete set of eligible one-worker additions/transfers, and every gain/cost is independently recomputed (`audit_last_worker.csv`). Selected-group tests separately check ranking against all eligible options. Browser scenario and marginal snapshots are freshly regenerated. Verified numbers live in `verified_presentation_claims.csv` with source paths and qualifications; no unverified preliminary 14/15-worker jumps or billion-simulation statements are included.

## 8. Runtime, tests and remaining conditions

**43 tests passed; 0 failed.** This includes the original tests with the erroneous coverage assertion corrected plus 13 new independent/adversarial cases. TypeScript and Vite production build pass. One non-failing Starlette/httpx test-client deprecation warning remains. The production app started on port 8001, executed real BASE/PEAK/DISRUPT controls, changed demand/availability, reported a genuine reduced-capacity Pharmacy minimum conflict, logged changes, inspected frontier, exported/downloaded and revalidated the CSV. Browser checks report no JavaScript page errors. Injected-error/retry test passes separately. Screenshots are acceptance evidence from the running audited app, not Prompt 3 demo polishing.

**Before the judged demo:**

1. Use the regenerated claims CSV, screenshots and submission; discard prior $322,980.81 DISRUPT cost and prior $997,870.925 three-scenario validation total. `docs/BUILD_REPORT.md` is explicitly historical.
2. State that probabilities and marginal effects are simulated-data model estimates, not observed Costco outcomes, guaranteed waits or causal safe staffing cuts. Explain low-probability plateaus when demonstrating severe disruption.
3. Disclose neutral central holiday adjustments, small backtest support, sensitivity rather than confidence bands, and aggregate qualification/weekly-hours semantics. No named roster or wall-clock cross-department transfer proof is possible from these inputs.

No known required software fix or environment blocker remains. Real-world service calibration, person-level qualification/hour validation and external operational deployment are outside this competition-data audit. Prompt 3 remains unexecuted. CONDITIONAL PASS must not be paraphrased as real-world operational certification.
