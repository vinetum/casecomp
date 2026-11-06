# PROMPT 3: FINAL DEMO, UX AND PRESENTATION READINESS

You are now the executive-demo director, frontend polish engineer, and release engineer for SHIFTWISE. Use the verified repository and `artifacts/INDEPENDENT_AUDIT.md`; do not replace mathematically validated behavior with precomputed fake outputs.

Goal: make a 3-4 minute live demo exceptionally understandable, reliable, and memorable within a 12-15 minute case presentation.

1. Rehearse the following story against actual computed output: the manager reviews BASE, PEAK increases demand, DISRUPT reduces available employees, and the system identifies a feasible schedule plus any residual risk. Show the 'Last Worker' decision, including BOTH the borrowing and lending departments' effects. If the prior illustrative Warehouse 2 / Feb 14 MID and Feb 13 OPEN cases are not convincing after verification, automatically choose a better demonstrated example from the 567 official rows and document the evidence.
2. Polish UI for a judge sitting far from the screen: large relevant metrics, strong hierarchy, one-click scenario changes, minimal navigation, restrained colors, clear `Projected` and `Simulated case` labeling, no ambiguous percentages, no information overload. Design deliberate before/after transitions and a clearly visible Recalculate action.
3. Include a built-in demo guide with at most six steps and an easily resettable state. Controls must execute real application logic. Add descriptive error states and a data-rich fallback screen if the solver times out. Do not turn fallback into fabricated results.
4. Optimize startup and computation. Produce reproducible local start commands, a smoke-test command, and an offline demo mode using bundled official source data and locally executed or source-derived calculations. Test with no internet after installation if possible.
5. Produce `artifacts/demo_run_of_show.md`: exact clicks, words to say, expected VERIFIED outputs or reasonable labeled ranges, backup screenshot paths, slide transition cues, and 3-minute and 4-minute versions.
6. Produce `artifacts/DEMO_ASSETS/` with real app screenshots and clean charts for the slide deck. Export `artifacts/presentation_evidence.json` describing validated metrics, source files, assumptions, and caveats. Remove or relabel any unverified numbers.
7. Re-run all tests and exports after UX changes. Verify original case source data is untouched, app still runs, and `TEAM_SUBMISSION_COMPLETED.csv` remains valid.

Do the work rather than only proposing enhancements. Report precise run commands, test results, deliverable locations, and anything the presenters must know before going on stage.
