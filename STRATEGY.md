# SHIFTWISE: Master Strategy and Project Context

## Texas MISA Fall 2026 Case Competition
### CGI-Sponsored Costco Workforce Planning Challenge

**Project:** SHIFTWISE: Workforce Resilience Command Center  
**Strategy:** The FORGE Framework  
**Signature Innovation:** The Last Worker  
**Repository:** `casecomp`  
**Objective:** Build a technically credible, operationally useful, and visually compelling workforce optimization solution capable of competing for first place.

---

# 1. PROJECT OVERVIEW

We are developing SHIFTWISE, an intelligent workforce planning and optimization platform for a simulated Costco operations case competition.

The system must predict customer demand, identify service risks, allocate available employees, respond to operational disruptions, and explain the business value of its recommendations.

The objective is not simply to minimize staffing costs.

It is to determine the best feasible allocation of employees that protects customer service while controlling labor expenses.

SHIFTWISE must be a functioning decision-support application, not merely a dashboard, static prototype, or slide presentation.

The final solution should combine:

- Demand forecasting.
- Service-risk prediction.
- Mathematical workforce optimization.
- Cross-trained employee allocation.
- Overtime management.
- Scenario simulation.
- Cost-service trade-off analysis.
- Explainable operational recommendations.
- An interactive web application.
- A validated staffing submission.

The original case materials and official assumptions are authoritative.

All case data is simulated and must not be represented as actual Costco operating information.

---

# 2. THE FORGE STRATEGY

Our overall solution follows five connected phases.

## F: Forecast Demand

Predict expected customer demand across each warehouse, department, date, and shift.

Use historical workload, calendar patterns, available contextual variables, and official scenario assumptions.

Validate forecasting accuracy using time-ordered backtesting.

Estimate forecast uncertainty rather than presenting predictions as guaranteed outcomes.

**Output:** Expected demand and uncertainty for every planning block.

## O: Optimize Staffing

Determine how many employees should work each shift and department.

Use mathematical integer optimization to balance service protection, labor costs, staffing minimums, and worker availability.

Account for regular employees, overtime, and qualified cross-trained employees.

**Output:** A cost-aware, feasible staffing recommendation.

## R: Reallocate Resources

Identify opportunities to move qualified employees between departments.

A cross-trained employee can be moved between Front End and Merchandising, but cannot work in both departments simultaneously.

Evaluate the effect of reallocation on both departments.

This phase contains our signature innovation, **The Last Worker**.

**Output:** The strongest feasible employee allocation, including cross-department trade-offs.

## G: Guard Service Levels

Protect checkout, replenishment, and pharmacy service targets.

Identify shifts approaching dangerous utilization levels.

When demand increases or employee availability decreases, recalculate staffing and identify remaining service risk.

If a service objective is impossible with the available workforce, report that limitation honestly.

**Output:** Service-risk projections, warnings, and feasibility explanations.

## E: Evaluate Outcomes

Compare staffing alternatives using labor cost, modeled service performance, feasibility, and resilience.

Analyze BASE, PEAK, and DISRUPT scenarios.

Show the cost-service frontier.

Explain why the selected recommendation is preferable to available alternatives.

**Output:** An evidence-based business recommendation and validated staffing submission.

### FORGE's central message

**Forecast demand. Optimize staffing. Reallocate resources. Guard service. Evaluate outcomes.**

The phases form a decision cycle. When conditions change, the system forecasts or updates demand, reoptimizes staffing, evaluates the resulting risks, and recommends the next action.

---

# 3. THE BUSINESS PROBLEM

Costco warehouse managers must allocate a limited workforce across departments and shifts.

Understaffing can create longer checkout lines, delayed merchandise replenishment, and slower pharmacy service.

Overstaffing increases labor expenses.

Operational conditions can change because of promotions, holidays, weather, or employee illness.

Some employees are qualified to work in more than one department, but moving them creates trade-offs.

Our central question is:

**Where should every available qualified employee be assigned to create the greatest operational value?**

This is more useful than simply asking how many employees each department wants.

---

# 4. CASE DATA AND SCOPE

## Warehouses

- Warehouse 1: Medium.
- Warehouse 2: Large.
- Warehouse 4: Large.

## Departments

- 38: Front End.
- 92: Merchandising.
- 95: Pharmacy.

## Shifts

- OPEN.
- MID.
- EVE.

## Historical period

January 1 through February 11, 2026.

## Planning period

February 12 through February 18, 2026.

## Scenarios

**BASE:** Expected demand and operating conditions.

**PEAK:** Increased demand associated with promotional activity and winter-weather concerns.

**DISRUPT:** Reduced staffing availability associated with employee illness and operational shortages.

The official source files define all scenario multipliers, staffing limits, and cost assumptions.

## Submission

The staffing submission requires 567 rows:

3 scenarios × 3 warehouses × 3 departments × 7 dates × 3 shifts.

The completed CSV must preserve the original submission template's exact structure and row keys.

Employee counts must be nonnegative integers.

Closed shifts must have zero employees.

The final submission must be independently validated.

---

# 5. SERVICE TARGETS

Front End:
Average checkout wait of five minutes or less.

Merchandising:
Replenishment response time of 60 minutes or less.

Pharmacy:
Prescription wait time of 20 minutes or less.

These service objectives are central to the optimization problem.

The goal is not to minimize labor spending without regard to service quality.

The goal is to protect service as efficiently as possible while respecting actual workforce constraints.

---

# 6. THE CENTRAL ANALYTICAL INSIGHT: THE SERVICE CLIFF

Earlier exploratory analysis identified a steep relationship between labor utilization and service performance in the simulated historical data.

Utilization can be expressed as:

`utilization = required_labor_hours / available_productive_labor_hours`

When utilization is low, employees have sufficient capacity to handle the workload.

As utilization rises, operational pressure increases.

Near certain utilization levels, even a small increase in workload or a small reduction in staffing may cause modeled service performance to deteriorate sharply.

Earlier exploratory findings suggested this relationship was particularly noticeable around 85% to 90% utilization in Front End and Merchandising.

Historical service-target attainment was approximately:

| Department | Historical attainment |
|---|---:|
| Front End | 77.0% |
| Merchandising | 69.9% |
| Pharmacy | 88.3% |

These are observations from the simulated case dataset.

They must be independently reproduced before being used as final presentation evidence.

The exact service-risk relationship must be validated separately by department.

Do not treat any utilization threshold as universal.

Do not interpret observational associations as guaranteed causal effects.

### Strategic implication

**The marginal value of an employee is not constant.**

An additional employee may have limited impact on a shift that already has sufficient coverage.

The same additional employee may have substantial modeled value on a shift operating near a service failure threshold.

This insight is the foundation of our Last Worker innovation.

---

# 7. SIGNATURE INNOVATION: THE LAST WORKER

The Last Worker is the most important differentiating feature of SHIFTWISE.

Imagine a warehouse manager has one additional qualified employee available.

Front End needs coverage.

Merchandising also needs coverage.

The employee cannot be assigned to both departments.

SHIFTWISE must determine where that employee creates the greatest net operational value.

The system should evaluate:

1. The service benefit of assigning the employee to Front End.
2. The service benefit of assigning the employee to Merchandising.
3. The consequences for any department lending that employee.
4. Incremental labor cost.
5. Remaining employee availability.
6. Qualification restrictions.
7. Feasibility of the allocation.
8. Overall service and cost trade-offs.

The recommendation must be calculated by the optimization engine.

Never hardcode the result.

### Illustrative preliminary example

Warehouse 2.

February 13, 2026.

OPEN shift.

Front End.

DISRUPT scenario.

Earlier exploratory modeling estimated:

- 14 employees: 36.4% modeled probability of meeting the service target.
- 15 employees: 98.0% modeled probability.
- Incremental shift labor cost: approximately $119.60.

These are preliminary model-based estimates, not observed outcomes or proven causal effects.

The final application must independently reproduce or replace these figures.

Do not force the application to generate these values.

The goal is to demonstrate the marginal value of an employee using defensible calculations.

---

# 8. SECOND INNOVATION: THE FEASIBILITY CERTIFICATE

Many staffing models recommend employee counts without verifying that enough qualified employees are actually available.

SHIFTWISE must avoid this mistake.

Every recommendation must respect the actual workforce constraints.

When a desired allocation cannot be achieved, the system should identify:

- Which constraint prevents the desired allocation.
- Which department is affected.
- The maximum feasible coverage.
- The best feasible alternative.
- Remaining service risk.
- Potential operational responses.

Distinguish between:

**Infeasible staffing:** Assigning more workers than are actually available or violating qualification and staffing rules.

**Feasible staffing with service risk:** Assigning only available qualified workers, but still facing the possibility of missing a service target.

A feasible plan may not be capable of achieving every service objective during a disruption.

The system must report this honestly.

Earlier exploratory research identified 10 distinct warehouse/date/shift groups in DISRUPT where the original draft allocation violated available staffing limits.

The final system must independently validate this finding.

---

# 9. THIRD INNOVATION: THE COST-SERVICE FRONTIER

SHIFTWISE should not provide a single unexplained staffing recommendation.

It should allow managers to explore different feasible operating priorities.

### Service First

Prioritize protecting service targets.

### Balanced

Seek a defensible compromise between service protection and labor expenditure.

### Budget Conscious

Limit labor spending while transparently identifying increased service risk.

The system should generate a cost-service frontier of feasible, nondominated staffing alternatives.

This allows decision-makers to understand how much additional spending is associated with improvements in modeled service performance.

The application must explain why one allocation is preferable to another.

---

# 10. FORECASTING APPROACH

The forecasting engine must predict demand for the planning week using historical data.

Candidate approaches should include:

- Two-week same-weekday averages.
- Three-week same-weekday averages.
- Four-week same-weekday averages.
- Supplied benchmark forecasts.
- Appropriate statistical or machine-learning models if justified by the sample size.

Use time-ordered backtesting.

Avoid future-data leakage.

Earlier exploratory rolling backtests produced approximately:

| Method | WAPE |
|---|---:|
| Three-week same-weekday average | 4.31% |
| Four-week same-weekday average | 4.74% |

These figures must be independently reproduced.

Do not assume that more complex forecasting models will necessarily outperform simpler approaches.

Account cautiously for Valentine's Day and Presidents' Day.

Apply the official scenario demand assumptions.

Forecasts must reconcile between daily and shift-level demand.

Future actual demand is unavailable, so planning-week performance must be described as projected rather than observed.

---

# 11. SERVICE-RISK MODELING

Use historical workload, staffing, productive labor capacity, and service outcomes to estimate service-target attainment.

Develop department-specific models.

Evaluate:

- Calibration.
- Brier score.
- Discrimination where applicable.
- Time-ordered validation.
- Sensitivity to forecast uncertainty.
- Robustness under alternative demand assumptions.

The simulated historical data may produce unusually steep service relationships.

Avoid unsupported certainty.

Predicted service probabilities should be labeled as model estimates.

If a model is poorly calibrated, improve it or use a documented conservative alternative.

---

# 12. MATHEMATICAL STAFFING OPTIMIZATION

Implement genuine integer optimization.

Recommended solver: OR-Tools CP-SAT.

The optimizer must:

- Respect regular employee availability.
- Respect overtime availability.
- Respect qualification restrictions.
- Enforce closed-shift zero staffing.
- Respect source-defined minimum staffing where feasible.
- Handle shortages honestly.
- Account for loaded hourly costs and paid shift hours.
- Optimize Front End and Merchandising jointly when sharing cross-trained workers.
- Prevent double-counting.
- Preserve Pharmacy qualification requirements.
- Return executable staffing recommendations.
- Report binding constraints and unresolved service risk.

The solver should prioritize service protection and cost efficiency using explicit objectives.

It must not fabricate additional workers.

Generate independent feasibility checks for all outputs.

---

# 13. PRELIMINARY RESEARCH FINDINGS

An earlier exploratory research process evaluated six utilization-based staffing policies under randomized demand conditions.

The research tested 20,000 randomized demand profiles per scenario.

This produced approximately 10.8 million simulated shift-demand observations and 75.6 million service-model evaluations across the candidate policies.

These were simulations of fixed staffing policies, not millions of independently optimized schedules.

A conceptual strategy design space contained approximately 1.129 billion possible combinations, but those combinations were not individually evaluated.

### Preliminary BASE comparison

| Policy | Estimated labor cost | Modeled service attainment |
|---|---:|---:|
| Original draft | $328,940 | 82.98% |
| 78% utilization | $348,538 | 96.17% |
| 80% utilization | $339,275 | 93.83% |
| 82% utilization | $330,606 | 90.03% |
| 84% utilization | $320,553 | 84.48% |
| 86% utilization | $313,121 | 78.23% |
| 90% utilization | $298,757 | 62.54% |

These are exploratory model projections.

The 82% utilization policy showed a potentially attractive service-cost trade-off, but it was not proven globally optimal.

Do not automatically use this policy as the final staffing submission.

The final optimizer must independently calculate its recommendations.

Do not claim these figures are actual realized results.

---

# 14. INTERACTIVE SCENARIO DEMONSTRATION

The live demo should show a clear progression.

### Scene 1: BASE

Show expected demand and the original draft schedule.

Explain the optimized recommendation.

### Scene 2: PEAK

Increase demand using the official PEAK scenario.

Show how staffing requirements and service risk change.

### Scene 3: DISRUPT

Reduce workforce availability.

Show how the optimizer responds to staffing shortages.

Highlight the Feasibility Certificate and remaining service risk.

### Scene 4: THE LAST WORKER

Present a situation in which departments compete for scarce qualified labor.

Evaluate alternative allocations.

Show why one decision is preferable according to the chosen objective.

### Promising demonstration location

Warehouse 2.

February 14, 2026.

MID shift.

Front End.

Earlier exploratory recommendations were:

- BASE: 37 employees.
- PEAK: 44 employees.
- DISRUPT: 30 employees.

The original draft had 31 employees.

These figures are preliminary heuristic results and are not final optimized recommendations.

The completed application must calculate its own results.

If another location produces a more compelling and defensible demonstration, use it instead.

---

# 15. APPLICATION ARCHITECTURE

Build a complete web application.

Recommended frontend:

- React.
- TypeScript.
- Vite.
- Tailwind CSS.
- Recharts.

Recommended backend:

- Python.
- FastAPI.
- pandas.
- NumPy.
- scikit-learn.
- OR-Tools.

Suggested application sections:

### Command Center

Overview of projected demand, labor cost, staffing, service risk, and operational warnings.

### Demand Intelligence

Historical trends, forecasts, validation, and uncertainty.

### Staffing Optimizer

Draft versus recommended staffing, employee allocation, costs, and service projections.

### Scenario Lab

Interactive BASE, PEAK, and DISRUPT simulations.

Allow managers to adjust demand and employee availability and recalculate actual recommendations.

### Decision and Export

The Last Worker, Feasibility Certificate, cost-service frontier, explanations, and completed staffing submission.

The interface should resemble a premium enterprise operations platform.

Prioritize readability, clarity, reliability, and polished visual design.

Do not build a static mockup.

---

# 16. PRESENTATION STRATEGY

The presentation should be approximately 12 to 15 minutes.

**Product name:** SHIFTWISE.

**Strategic framework:** FORGE.

**Presentation theme:** The Last Worker.

**Core message:** The right worker in the right department at the right time creates more value than simply increasing total headcount.

Recommended presentation:

1. The Last Worker opening dilemma.
2. The business challenge.
3. Historical data findings.
4. The service cliff.
5. Demand forecasting and validation.
6. Introducing SHIFTWISE and FORGE.
7. How the decision engine works.
8. BASE scenario demonstration.
9. PEAK scenario demonstration.
10. DISRUPT scenario and Last Worker demonstration.
11. Cost-service frontier and limitations.
12. Implementation recommendation and conclusion.

Use actual screenshots from the completed application.

Use verified numerical results.

Avoid excessive technical jargon.

The live demonstration should be the most memorable part of the presentation.

### Suggested opening

"Imagine you're managing a Costco warehouse. Customer demand is rising, employees are calling out, and you have one qualified worker available to move. Front End needs help. Merchandising needs coverage. You cannot put that worker in both places. Who gets the last worker?"

### Suggested closing

"The future of workforce planning isn't simply knowing how many workers you need. It's knowing where every worker matters most."

---

# 17. COMPETITIVE DIFFERENTIATION

Other teams may produce forecasting dashboards, scheduling algorithms, or visual simulations.

SHIFTWISE should distinguish itself through a complete decision-making process.

Our strengths should include:

1. Accurate, validated forecasting.
2. Service-risk analysis.
3. Constraint-aware mathematical optimization.
4. Cross-department worker conservation.
5. Honest infeasibility detection.
6. Marginal employee value analysis.
7. Cost-service trade-offs.
8. Interactive scenario testing.
9. Explainable recommendations.
10. Strong presentation storytelling.

Do not sacrifice mathematical correctness for visual effects.

Do not overengineer features that make the application unreliable.

The best competition submission is one that is credible, useful, and demonstrably functional.

---

# 18. CODEX IMPLEMENTATION WORKFLOW

The GitHub repository is `casecomp`.

The user wants Codex to generate the entire application without requiring manual coding.

There are three implementation stages.

### Stage 1: Master Build

Follow `01_CODEX_MASTER_BUILD.md`.

Build the full application, forecasting pipeline, service model, optimizer, simulator, and staffing CSV.

### Stage 2: Independent Audit

Follow `02_CODEX_INDEPENDENT_AUDIT.md`.

Verify data handling, calculations, staffing constraints, model results, and final outputs.

Fix defects.

### Stage 3: Demo Polish

Follow `03_CODEX_DEMO_POLISH.md`.

Improve the interface, rehearse the live demonstration, create screenshots, and prepare final presentation assets.

Do not execute all three stages simultaneously.

Finish and validate each stage before proceeding to the next.

After the application is complete, use ChatGPT Work to generate the presentation from verified outputs.

---

# 19. REQUIRED FINAL DELIVERABLES

The project must produce:

- A working web application.
- Demand forecasting and validation.
- Service-risk prediction.
- Mathematical staffing optimization.
- BASE, PEAK, and DISRUPT scenario simulations.
- The Last Worker decision feature.
- The Feasibility Certificate.
- Cost-service frontier visualization.
- A completed 567-row staffing CSV.
- Independent validation results.
- A polished live demonstration.
- Presentation-ready screenshots and charts.
- A complete methodology explanation.
- A professional competition presentation.
- Speaker notes and script.
- Appendix and judge Q&A.

The original competition rules take priority if they differ from this document.

---

# 20. NONNEGOTIABLE PRINCIPLES

1. Do not invent data, employee availability, labor costs, or service outcomes.
2. Do not hardcode demonstration results.
3. Do not double-count cross-trained employees.
4. Do not violate qualification restrictions.
5. Do not claim that model projections are observed results.
6. Do not claim causal effects without supporting evidence.
7. Do not claim globally optimal solutions without solver verification.
8. Do not claim that the team ran one billion actual simulations.
9. Do not submit an infeasible staffing plan without explicitly addressing the problem.
10. Do not create presentation claims that differ from the final verified application.
11. Do not replace the application with a static dashboard.
12. Prioritize reliable functionality, explainability, and mathematical credibility.

---

# 21. FINAL VISION

SHIFTWISE should answer five questions for a warehouse manager:

**What demand should we expect?**

**Where are we at risk of failing service targets?**

**How should we allocate our available workforce?**

**What happens when conditions change?**

**Where does the next available employee create the greatest value?**

The FORGE framework provides the process.

SHIFTWISE provides the technology.

The Last Worker provides the memorable decision.

Together, they form a complete workforce optimization strategy designed to protect service, control costs, and respond intelligently to operational disruptions.

**Our final goal is to demonstrate that the best workforce plan is not simply the cheapest or the largest. It is the most effective feasible allocation of available employees.**
