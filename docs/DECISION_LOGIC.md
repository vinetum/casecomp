# Decision logic

1. Forecast BASE department demand from history. Apply exact official scenario adjustments and closed-block zeros.
2. If requested, stress demand and reduce existing source pools using floor(integer capacity × availability factor). Availability cannot exceed the source pool.
3. Jointly solve Front End/Merchandising and licensed-only Pharmacy using canonical costing, minimum staffing, service tolerance and cost tie-breaks. Equal quantized service scores prefer lower cost. A lower-bound probability plateau is an explicit model limitation, not evidence that extra staffing has no real operational value.
4. Independently verify the totals. Distinguish staffing infeasibility from feasible staffing with service risk.
5. Recompute draft comparisons using the same demand. An unavailable draft remains hypothetical, never a valid alternative.
6. Produce the Feasibility Certificate: source caps, binding pools, safety deficits, standalone maxima and attainable joint modeled service. Actions suggest categories; they do not assert extra workers exist.
7. Compute The Last Worker by considering every one-worker eligible addition and each FE↔MS transfer. Reapply the full allocation rules and staffing minimums. Net expected-target gain = sum of the changed probabilities, including the lender. CP-SAT chooses the highest quantized net benefit and cheapest tied alternative. If no change gives positive value at 0.000001 precision, retain the current allocation; do not force a dramatic recommendation. Pharmacy can add its own unused qualified capacity but cannot participate in cross-department transfers.
8. Solve eight service tolerances (0, 1, 2, 4, 6, 10, 15, 25 percentage points) and remove dominated/duplicate plans. Managers can inspect each point's allocations.
9. Construct explanations deterministically from the selected constraints, counts, modeled probabilities and costs. No LLM controls allocations.
10. Export the independently validated full official Service First submission. Custom simulation inputs or mode changes intentionally do not overwrite the competition artifact; the UI states this before download.

The Last Worker is a marginal decision relative to the **currently selected plan**, so a fully service-maximized plan often has no beneficial addition. Use Balanced to inspect the cost of recovering service forgone for budget reasons. A higher recipient probability alone never proves a transfer is beneficial: the lender's loss must be included.
