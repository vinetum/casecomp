# Facts, assumptions, estimates and unknowns

| Category | Treatment |
|---|---|
| Dataset facts | Original simulated CSV/workbook/PDF, warehouses 1/2/4, departments 38/92/95, dates and exact multipliers, aggregate qualified availability, paid hours, labor standards, cost rates and service-minute targets. |
| Forecast assumptions | Six weeks describe future weekday structure; historical day-type shares approximate next-week shares. Holiday analogue shrinkage is a tested candidate, not a mandatory uplift. Selected central forecast has neutral calendar adjustment if no defensible candidate wins. |
| Optimization preferences | Equal-weight open-block probabilities; service-first official export; 2/6 point service-loss tolerances for exploratory modes; 0.000001 probability precision; 95% risk alert threshold. |
| Model estimates | Demand, target-attainment probability, marginal worker benefit, projected labor cost and cost-service frontier. Never actual future outcomes, causal effects, realized savings, or minute forecasts. |
| Sensitivity assumptions | Residual-based stress bounds plus 10 points for holiday windows; slider adjusts demand 70–150% and availability 0–100% of official pools. Reduced capacity is floored to integer employees. Bands are not confidence intervals. |
| Unknowns | Individual qualifications, named employees, exact weekly hours, shift transitions, future demand and realized wait times. The source aggregation reflects weekly limits but cannot independently prove them per person. |

The official case permits FE/MS sharing by warehouse/date/shift label even though department wall-clock blocks differ. We follow that aggregate grain and do not claim an executable individual transfer roster. Incoming flex caps describe qualified employees **from the partner**, so unused regular partner availability is also required. No Pharmacy sharing is allowed.

Service models have unusually strong discrimination on simulated data. This is not evidence of real-world reliability. Training span is short, holiday examples are rare, selection scores can be optimistic, out-of-support counterfactuals are unvalidated, and uncertainty is not propagated as a full joint demand distribution. There is no independent planning-week actual outcome to evaluate. Warehouse effects and minute-level regression are omitted rather than presented without validation.

The four-week forecast comparator also reconstructs the supplied benchmark; the application does not claim to beat it. Frontier points are a finite sampled set. Solver optimality is limited to the specified aggregate finite model. Staffing counts are block assignments, not unique weekly employees. DISRUPT draft cost/service is hypothetical where capacity is violated; reducing spending because workers are unavailable is not a productivity gain.

Technical scope: single-process local proof of concept, no login, no production authorization, no external scheduling integration, no persistent user edits and no external LLM. Source data and versioned artifact generation make this competition workflow reproducible. Runtime initialization retrains models and solves 189 official groups; allow approximately 20–60 seconds depending on hardware. Services must restart after restoring an environment snapshot. Prompt 2 is documented in artifacts/INDEPENDENT_AUDIT.md. Prompt 3 remains unexecuted.
