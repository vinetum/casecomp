# PROMPT 2: INDEPENDENT AUDIT AND SOLVER HARDENING

You have access to the SHIFTWISE repository. Do not assume that the first build is mathematically correct. Act as an independent skeptical reviewer and test engineer. Read the original case PDF, README, assumptions, data dictionary, submission template, source CSVs, code, and current test results.

Your task is to find and repair problems rather than merely compliment the app.

1. Build an independent data and business-rule validator, preferably separate from the implementation under test. Check 567 exact submission keys, valid integer staffing, closed = 0, minimum staffing, scenario identity, official demand multipliers, and correct source columns.
2. Audit integer optimization: worker conservation, regular capacity, partner cross-training opportunity cost, no double-counting, overtime limits, Pharmacy restrictions, infeasible minimums, and dynamic what-if behavior. Generate edge cases, including zero workforce, exactly-one-borrowable-worker, both departments requesting the same worker, closed Pharmacy shifts, and worst-case DISRUPT. Confirm the optimizer does not create workers.
3. Independently recompute loaded regular/overtime cost and total staffing from allocation traces. Verify source-first regular, flex and overtime costing. Compare plan vs draft consistently and label non-executable drafts.
4. Recheck all forecast features for future leakage. Re-run rolling tests using only prior observations at each prediction date. Test that shift predictions reconcile to daily forecasts. Measure service model calibration, uncertainty and overly steep probabilities, and document limitations of synthetic data.
5. Test service-first decision quality against multiple heuristic baselines. Search for counterexamples where a plan is dominated: another feasible plan achieves equal or better expected service at less cost. Produce a verified nondominated frontier where computationally practical. Explain whether the current optimizer is globally optimal for its stated objective, approximately optimal, or merely heuristic.
6. Re-run scenario demo calculations; independently verify any numeric claim chosen for the presentation. Replace any invalid or overly certain number. In particular, treat earlier 82% headcount examples and 'Last Worker' service jumps as hypotheses to test, never preverified facts.
7. Launch and inspect the application in a browser or available UI runner. Toggle all three scenarios, change availability and demand, click Recalculate, inspect logs, run export, load exported CSV back into validator. Ensure displayed values genuinely update.
8. Fix failures; rerun tests. Record each issue in `artifacts/INDEPENDENT_AUDIT.md` with severity, reproducible evidence, repair, and remaining concerns. Generate `artifacts/verified_presentation_claims.csv` containing ONLY verified numbers and source paths.

Do not declare success based on passing self-written happy-path tests alone. Include adversarial tests and mathematical consistency checks. Finish with a clear PASS / CONDITIONAL PASS / FAIL decision and exactly what remains to fix before the judged demo.
