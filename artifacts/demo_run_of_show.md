# SHIFTWISE live run of show

Use the audited corrected CSV and current DEMO_ASSETS. All numerical effects below are projections from the executed local API, not observed or causal effects.

## Before the audience arrives

Run `./scripts/demo.sh` after installation. Wait for “demo ready”. It calculates and warms the four distinct official selections. Open port 8000 in a browser. Use a 1600×1100 or larger viewport; browser zoom 90–100%. Click Start guided demo. Reset always returns to Scene 1, official BASE, Service First. Do not alter source inputs.

## Four-minute version

| Time / slide cue | Exact click | What appears and what to say | Backup |
|---|---|---|---|
| 0:00–0:40 / diagnosis | Start guided demo | Front End: 31 draft → 35 recommended; Merchandising: 17 draft → 17 recommended; Pharmacy: 3 draft → 2 recommended. Selected-group projected cost $6,614.46; mean modeled target probability 99.5%. Start with the expected week. These are full-block employee assignments, not unique people. | `DEMO_ASSETS/01-BASE.png` |
| 0:40–1:20 / pressure | Click 2 PEAK | Front End: 31 draft → 42 recommended; Merchandising: 17 draft → 19 recommended; Pharmacy: 3 draft → 2 recommended. Selected-group projected cost $7,963.51; mean modeled target probability 99.5%. Promotion and weather increase official demand. The same capacity must do more work. | `DEMO_ASSETS/02-PEAK.png` |
| 1:20–2:10 / resilience | Click 3 DISRUPT | Front End: 31 draft → 6 recommended; Merchandising: 17 draft → 17 recommended; Pharmacy: 3 draft → 2 recommended. Selected-group projected cost $3,617.90; mean modeled target probability 66.5%. Illness changes availability. A feasible plan may still have severe modeled service risk; low-probability plateaus are not evidence that real workers have no value. | `DEMO_ASSETS/03-DISRUPT.png` |
| 2:10–3:10 / signature decision | Click 4 LAST WORKER | Balanced mode: add unused eligible capacity to Merchandising; recipient +5.14 pp, lender 0.00 pp, incremental $187.20. The borrowing alternative has net expected-target change -0.3603. Both departments matter; do not choose on recipient gain alone. | `DEMO_ASSETS/04-LAST-WORKER.png` |
| 3:10–4:00 / recommendation | Click 5 DECIDE & EXPORT; inspect frontier; click Download 567-row official plan | Regular pools include outgoing loans once. Pharmacy never shares. Costs and service are projections. Export covers all official scenarios in Service First; this Balanced scene does not overwrite it. Close with: “The right worker, in the right place, within real limits.” | `DEMO_ASSETS/05-DECISION-EXPORT.png` |

## Three-minute cut

Spend 25 seconds each on BASE and PEAK, 40 on DISRUPT, 55 on Last Worker and 35 on certificate/frontier/export. Use the same five clicks and actual outputs; omit the forecast-method appendix and alternative-option exploration. At 2:25 move to Scene 5.

## Optional five-minute discussion

Exit presentation, open Scenario Lab, select warehouse 2, planning date Feb 14, MID shift and BASE. Move Demand multiplier to 125% and Available workforce to 80%, then click Recalculate. The Saturday Pharmacy pool can conflict with its minimum; explain that capacity-feasible best effort is not a valid minimum-staff schedule. Restore official assumptions before returning to the guide.

## Failure and offline rehearsal

No Internet is required after installation: all inputs, models, fonts and application code are local. Browser acceptance blocks every external hostname, and the Python test forbids outbound socket connections during model generation. If the solver times out, the app hides the stale recommendation and shows labeled official week reference totals. Retry once or reset assumptions. If the local server is unavailable, switch to the matching DEMO_ASSETS screenshot and explicitly call it a captured model result. Never imply the backup is a fresh calculation.

## Presenter guardrails

The forecast matches the supplied benchmark within rounding; do not claim it beats the benchmark. Six-week simulated history cannot prove a new holiday effect or real-world causal staffing benefit. Stress ranges are not confidence intervals. The frontier samples eight service tolerances. Equal-weight attainment excludes closed blocks. Standalone certificate maxima are not jointly additive. The 567-row CSV and audit remain the submission authority.

Sources: `DEMO_ASSETS/live_demo_decisions.json`, `verified_presentation_claims.csv`, `INDEPENDENT_AUDIT.md`, `scenario_summary.csv`.
