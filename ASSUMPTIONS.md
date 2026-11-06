# Assumptions and Data Generation

**All data is simulated for a student competition. It is not Costco data and does not represent Costco wages, staffing levels, schedules, or service performance.**

## 1. Demand
- Daily demand is `transaction_count_proxy` in `API.FactDailyTrainingLaborOutput` (six weeks of history).
- It is split into three shifts using a department and day-type demand mix with day-to-day variation; on holiday-window days, Front End demand shifts toward midday. The three shifts always sum exactly to the daily value.
- Units are department-specific workload proxies, not literal transactions, prescriptions or cases. Do not compare units across departments.

## 2. Shifts
Non-overlapping planning blocks. Headcount = employees working the full block. Assumed warehouse hours: weekdays 10:00-20:30, Saturday 09:30-18:00, Sunday 10:00-18:00.

| Department | Weekday (OPEN / MID / EVE) | Saturday | Sunday | Min staff when open |
|---|---|---|---|---|
| Front End | 09:00-13:00 / 13:00-17:00 / 17:00-21:00 (4 / 4 / 4 h) | 4 / 3.5 / 2.5 h | 4 / 3 / 2.5 h | 4-6 |
| Merchandising | 04:00-10:00 / 10:00-15:00 / 15:00-21:00 (6 / 5 / 6 h) | 5.5 / 4.5 / 4.5 h | 5 / 4 / 4.5 h | 3-6 |
| Pharmacy | 09:30-13:00 / 13:00-16:00 / 16:00-19:30 (3.5 / 3 / 3.5 h) | 4 / 5 h / closed | closed / 5 h / closed | 2 |

## 3. Staffing
- **Labor standard** (labor hours per workload unit at 100% productive time): Front End 1.50, Merchandising 1.20, Pharmacy 0.165. Real operations cannot run at 100%; choosing a target utilization is your decision.
- **Historical schedules** were built the way many managers schedule: from typical weekday patterns, with warehouse-specific habits and limited adjustment for holidays. Some blocks are systematically over- or under-staffed. Finding where is part of the case.
- **Callouts** occur at department-specific rates, are higher on weekends and after holidays, and include a flu-season cluster at Warehouse 2 in late January. About half of callouts were backfilled with overtime when overtime capacity allowed.
- **The draft schedule** for the planning week rolls the managers' usual pattern forward. It does not adjust for Presidents' Day, Valentine's Day or any scenario.

## 4. Availability
- `available_regular_employees`: qualified staff available at straight time, net of PTO and illness. Holiday-weekend PTO requests reduce it on Feb 14-16.
- `max_overtime_employees`: additional staff who could work the block at overtime rates (about 20% of the normal pool).
- `cross_trained_flex_employees`: Front End and Merchandising staff qualified to cover each other at the regular rate. Each one used is one fewer available in the other department for that shift. Pharmacy has none (licensure).
- Aggregated by block; no individual employee records. Weekly 40-hour limits are reflected in availability rather than tracked per person.

## 5. Labor cost
- Base wage by department (Front End $23.00, Merchandising $24.00, Pharmacy $40.00 blended pharmacist/technician) x warehouse factor (1.00 / 1.04 / 1.02 for warehouses 1 / 2 / 4). These are illustrative, not Costco pay rates.
- Loaded regular rate = base x 1.25 (payroll taxes + benefits). Loaded overtime rate = base x 1.5 x 1.10 (payroll taxes only; benefits are not re-applied to overtime hours). Overtime is therefore about 32% more expensive per hour, not 50%.
- Block cost = (regular + flex employees) x paid hours x loaded regular rate + overtime employees x paid hours x loaded overtime rate.
- **How submitted plans are costed:** you submit total employees per block. Every team's totals are allocated the same way: regular staff first, then cross-trained staff the partner department is not using in that shift, then overtime.

## 6. Service levels
- One metric per department: Front End average checkout wait (target 5 min), Merchandising replenishment response (target 60 min), Pharmacy prescription wait (target 20 min). Lower is better.
- Simulated from demand relative to **worked** labor hours, with random variation and warehouse-to-warehouse process differences. Service degrades gradually at moderate utilization and very steeply as utilization nears capacity. Teams should estimate this relationship from history (example query Q4b in `06_Example_Queries.sql` is a starting point).

## 7. Scenarios (planning week Thu 2026-02-12 to Wed 2026-02-18) - all three are required
| Scenario | Demand | Availability |
|---|---|---|
| **BASE** | Your forecast (multiplier 1.00). Includes Valentine's Day and Presidents' Day, which you must forecast. | Planned availability, including holiday-weekend PTO |
| **PEAK** | BASE x multipliers for a promotion launch plus a winter-storm advisory: Front End and Merchandising +10% to +30% on Feb 13-14 (stronger at Warehouse 4), +6% on Feb 15; Pharmacy +5% | Same as BASE |
| **DISRUPT** | Same as BASE | Warehouse 2 illness cluster Feb 13-16 (Front End about -30%, one pharmacy team member out per block, overtime capacity halved); Warehouse 4 opening stocking crew about -35% on Feb 12-13 |

## 8. Benchmark forecast
`src.FactDailyPrediction` model_run_id 2026021101 is the average of the same weekday in weeks 3-6. It ignores holidays, promotions and weather. It is a floor to beat, not a recommendation.
