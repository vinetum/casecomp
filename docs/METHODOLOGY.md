# SHIFTWISE methodology — Prompt 1

All inputs are simulated competition data. Forecasts, probabilities and costs are modeled projections, not observed Costco results. Original PDF and supplied assumptions take precedence. No exploratory research numbers are used as training labels or forced recommendations.

## Sources and audit

`data/raw/` contains byte-for-byte copies of the original 16 CSV inputs, Excel workbook and case PDF. Root originals remain available; the original README is preserved in `docs/ORIGINAL_README.md`. `backend/data.py` checks expected counts, composite keys, nonnegative integer capacities, closed blocks, source-table/view correspondence, calendar ranges, rates, durations, actual worked accounting, labels, daily reconciliation and all nine workbook data sheets against CSVs. Audit checks and SHA-256 CSV hashes are exported. SQL Server is unnecessary; CSV views contain the required planning workflow. SQL Q5 explicitly warns that its starter example does not conserve lender capacity; SHIFTWISE does.

## Demand forecast

Daily historical demand is taken once per warehouse/department/date, not repeated across shifts. Closed New Year's Day is excluded from fitting. Two seven-day forecasts originate Jan 29 and Feb 5, 2026; each uses data strictly before its origin, without updates from the holdout week. Candidates are 2-, 3- and 4-week same-weekday means; a three-week mean with shrunk historical calendar analogues; and a strongly regularized log-demand ridge model with weekday, holiday, promotion and temperature. Ridge is fit separately per warehouse/department with 27–34 training days, so complexity is deliberately limited.

WAPE = absolute error sum / actual demand sum **within** a warehouse/department. MAE and WAPE are reported for all nine groups. Selection uses the macro mean of those nine WAPEs. Incompatible department units are never pooled to compute an overall workload total. Two folds provide limited model-selection evidence, not an additional untouched test set or evidence of future accuracy.

The supplied benchmark is a planning-week four-week weekday mean; there are no planning-week actuals with which to score it. The four-week reconstructed rolling method is its historical comparator. The selected method is recorded in `model_metrics.json`. It is not assumed to beat the supplied benchmark. `forecast_vs_benchmark.csv` compares the actual future forecasts without inventing future accuracy.

Historical holiday ratios are computed against normal same-weekday means, pooled within department, with a prior of three independent calendar dates: factor = 1 + (mean ratio − 1) × n/(n+3), bounded to [0.85, 1.20]. Pre-MLK dates are an imperfect Presidents Day analogue. There is no Valentine's Day training example, and New Year rebound is not used as a Presidents Day rebound analogue. Calendar adjustment is applied only if that candidate is selected; otherwise the central forecast remains neutral and the analogue is exported for sensitivity context. Rare holiday effects cannot be validated from this small sample.

Shift shares use historical open-block average shares for the same warehouse, department and day type, normalized to sum to one. Daily forecasts reconcile exactly to the BASE shift forecasts. PEAK uses each exact official shift demand multiplier; DISRUPT has BASE demand and its own source availability. Closed blocks have zero demand.

The sensitivity envelope uses the selected method's department-level 90th percentile absolute relative backtest residual, plus a disclosed ten percentage points on non-Normal planning calendar days. These are stress bounds, **not calibrated confidence or prediction intervals**. Their coverage is not guaranteed. The Scenario Lab reruns the optimizer at a selected stress point; it is not a stochastic robust-optimization claim.

## Service models

Only historical actual workload and worked hours enter utilization:

`u = shift demand × department labor standard / worked labor hours`.

Separate department models predict whether the source-defined minute threshold is met (5 / 60 / 20). Candidates are decreasing logistic models at C ∈ {1,10,100,1000} and decreasing isotonic regression. Fit through Jan 21; choose using Brier score on Jan 22–28; refit through Jan 28 and evaluate once on Jan 29–Feb 11. Final operational models refit through Feb 11 using the previously selected model family. No warehouse effects are included because the short sample does not justify additional parameters. Isotonic is a transparent monotone alternative, not a hidden hand-tuned cliff.

Metrics include sample counts, Brier, constant-rate baseline Brier, AUC when defined, five calibration bins and ECE. Test counts are 126 Front End, 126 Merchandising, 108 Pharmacy blocks. `service_calibration.png` visualizes held-out calibration. Probabilities are bounded to [0.005, 0.995] to avoid unsupported certainty; outside training support the monotone models extrapolate conservatively to their bounded endpoints, but these estimates remain unvalidated. No validated minute-level wait-time model is claimed. Staffing changes are observational counterfactual projections, not demonstrated causal effects.

## Joint integer optimization

Each warehouse/date/shift/scenario is independent under the supplied aggregate availability semantics. Enumerate the full feasible finite headcount domains for the FE/MS pair, and separately for Pharmacy. For receiving department i and partner j:

- local regular_i = min(total_i, regular_available_i)
- unused_partner_j = max(regular_available_j − total_j, 0)
- flex_i = min(max(total_i − local_regular_i, 0), flex_cap_i, unused_partner_j)
- overtime_i = total_i − local_regular_i − flex_i

Reject overtime above its cap, any Pharmacy borrowing, and nonzero closed staffing. Thus a local regular employee cannot also be lent, and a department cannot manufacture an unused partner worker by paying its own worker overtime. Source hours and receiving department loaded rates determine cost. Half-hour blocks can produce half-cent costs; CP-SAT uses integer thousandths of a dollar, preserving source precision rather than rounding away differences.

CP-SAT has explicit integer total/local/flex/overtime variables constrained to allowed assignment tables. Its service objective is the equal-weight sum of open-block target probabilities, quantized at 0.0001. First minimize total minimum-staff shortfall; restrict all choices to that achievable minimum. The maximum service score follows exactly from the independent pair and pharmacy tables. A workload-coverage tie-break (sum of min(productive capacity / required labor, 1)) distinguishes plans with identical quantized probabilities. This prevents the bounded low-probability plateau from making an almost-unstaffed shift appear equivalent to the strongest available coverage; it does not alter the probability estimates. Probability score is strictly primary using a coverage radix greater than the maximum three-department coverage sum. Then require a service score within the chosen tolerance of that maximum and minimize cost; finally maximize service at the minimum cost to eliminate cost ties. All optimization solves must report OPTIMAL or the operation returns an error rather than claiming optimality.

Modes permit mean modeled attainment loss from the attainable maximum: Service First = 0, Balanced = 0.02, Budget Conscious = 0.06. These tolerances are explicit analyst preferences, not competition facts. The official export uses Service First for all three scenarios. Optimality applies to this finite aggregate model and probability precision, **not** real-world service, individual rosters or all business objectives.

If even minimum staffing is impossible, return a capacity-feasible best effort, label MINIMUM_CONFLICT, show the shortfall and fail strict feasibility. Do not invent employees or export such a simulation as a valid submission. Official source scenarios currently admit minimum-feasible recommendations.

## Independent verification and outputs

`backend/verify.py` does not import the optimizer. It validates exact unique keys, integers, closures and minimums, reconstructs allocations from totals and source capacities, and recalculates costs. Tests compare solver allocations/cost against that independent implementation and an exhaustive small fixture. The 567-row submission preserves the template's original row order and every fixed metadata column. Only team ID and employee values change.

Draft probabilities/cost use the same forecast and canonical convention, but an infeasible draft is explicitly hypothetical and non-executable. Counts are employee **block assignments**, not unique people. Equal-weight mean probabilities exclude closed blocks and are not demand-weighted throughput or observed service attainment.

The frontier shows nondominated points among eight solved tolerances, not every possible efficient plan. Per-department standalone maxima in the certificate can compete for the same workers and should not be added. A 95% modeled attainment threshold is a diagnostic preference, not a case rule or guarantee. All reports are regenerated by `scripts/export.sh`; all numbers in the interface originate in source data or these calculations.
