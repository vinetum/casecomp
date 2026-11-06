# Judge Q&A — evidence appendix

**Is this real Costco information?** No. Every input is simulated competition data. We clearly separate historical simulated observations from planning estimates.

**Did ML beat the benchmark?** No such claim. We compared weekday means and a regularized ridge model on past-only weekly folds. The selected four-week method reconstructs the supplied benchmark, with macro WAPE in `model_metrics.json`; future actuals do not exist. Simplicity was supported by the available sample.

**Where are Valentine's Day and Presidents Day effects?** We evaluate shrunk historical calendar analogues, but a single historical holiday cannot validate a new uplift. The selected method keeps a neutral central effect, exports analogue support and widens the sensitivity envelope on holiday-window dates. PEAK adjustments still use exact official multipliers.

**Is the optimizer genuine?** Yes. OR-Tools CP-SAT chooses explicit integer totals/regular/flex/overtime from complete canonical feasible domains. It minimizes staffing shortfall, preserves a selected level of modeled service, minimizes cost, then breaks cost ties on service. OPTIMAL status is required. A separate verifier and independent exhaustive fixture test the result.

**Can a cross-trained employee be counted twice?** No. Flex is bounded by both the receiving qualification cap and unused regular partner pool. Local regular plus outgoing loans cannot exceed the same source pool. Pharmacy never shares.

**What happens if minimum staffing is impossible?** The engine returns a capacity-feasible best effort, reports the precise minimum conflict and refuses a valid-submission claim. It never creates workers. Official scenarios currently permit minimum-feasible plans.

**Does 99% predicted service mean guaranteed five-minute checkout?** No. It is an estimated probability of the department-specific target under a fitted simulated-data model. Calibration/Brier/AUC are held out by time. No causal or minute-level guarantee is made.

**Why no Last Worker recommendation sometimes?** Under Service First, the best attainable service may already be achieved. A transfer that helps one department can harm another more. The system explicitly recommends retaining the allocation when no feasible positive net change exists at the stated precision.

**How is cost calculated?** Source paid hours × source receiving department loaded rate; regular and flex first, overtime last. Rates are already loaded. We do not add the benefits burden again. Internal precision preserves half-cent amounts from half-hour shifts.

**Why is the DISRUPT plan cheaper?** Staffing is unavailable in some blocks. That is not a realized efficiency gain. The app reports remaining risk and labels the original infeasible draft as hypothetical.

**What is the service frontier?** Nondominated alternatives among eight solved tolerances, not an exhaustive enumeration of every efficient plan. Stress controls rerun that comparison.

**Is this an individual roster?** No; aggregate data cannot prove per-person licensure, wall-clock transfers or weekly hours. The case's aggregate availability already reflects those weekly limits.

**How do we reproduce the submission?** Run `scripts/export.sh --team-id YOUR_TEAM`, then `.venv/bin/python -m scripts.validate_submission`. Tests verify exact metadata/order, 567 integers, closed zeros, minimums, pool conservation and independent costs.
