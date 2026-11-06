# Data Dictionary

Covers the shift-level planning tables and views (schema `comp`) and the planning-week rows in the core tables. Core daily columns (sales, traffic, holiday, weather, promotion) are described in `model.ModelFeatureRegistry`.

**Value categories:** *Historical* = simulated past actuals. *Forecast* = known or expected at planning time. *Planned* = management's current plan or a team's submission. *Derived* = calculated from other fields. *Assumed* = case assumption you may challenge. *Scenario-generated* = created to define a scenario. *Key* / *Label* = identifiers and descriptive text.

Grain of all fact tables: **warehouse (store_id 1, 2, 4) x department (dept_id 38 Front End, 92 Merchandising/Stocking, 95 Pharmacy) x date x shift (OPEN, MID, EVE)**.


## comp.DimShift

| Column | Type | Category | Purpose |
|---|---|---|---|
| `shift_code` | NVARCHAR(10) | Key | Shift identifier: OPEN, MID, EVE. PK. |
| `shift_name` | NVARCHAR(50) | Assumed | Display name: Opening, Midday, Evening. |
| `shift_sequence` | TINYINT | Assumed | Sort order within the day (1-3). |

## comp.ShiftDefinition

| Column | Type | Category | Purpose |
|---|---|---|---|
| `dept_id` | SMALLINT | Key | Department (FK API.DimDepartment). PK part. |
| `day_type` | NVARCHAR(10) | Key | Weekday, Saturday or Sunday (shift times differ by day type). PK part. Holidays use the Weekday definition unless the warehouse is closed. |
| `shift_code` | NVARCHAR(10) | Key | FK comp.DimShift. PK part. |
| `shift_start_time` | TIME(0) | Assumed | Block start time. NULL when the department is closed in that block. |
| `shift_end_time` | TIME(0) | Assumed | Block end time. NULL when closed. |
| `paid_hours` | DECIMAL(4,2) | Assumed | Paid hours per employee assigned to the block (= shift length used for all cost and capacity math). 0 when closed. |
| `is_open` | BIT | Assumed | 1 if the department operates in this block on this day type. |
| `min_staff` | SMALLINT | Assumed | Minimum employees whenever the block is open (safety / coverage floor; Pharmacy = 1 pharmacist + 1 technician). |
| `value_type` | NVARCHAR(30) | Label | Always 'Assumed'. |
| `notes` | NVARCHAR(400) | Label | Free-text clarification. |

## comp.LaborStandard

| Column | Type | Category | Purpose |
|---|---|---|---|
| `dept_id` | SMALLINT | Key | Department. PK, FK API.DimDepartment. |
| `workload_unit_definition` | NVARCHAR(400) | Assumed | What one demand unit means for the department. Units are scaled proxies and are NOT comparable across departments. |
| `labor_hours_per_workload_unit` | DECIMAL(6,3) | Assumed | Engineered standard: labor hours per demand unit at 100% productive time. Required hours = demand x standard / target utilization (teams choose utilization). |
| `standard_basis` | NVARCHAR(400) | Label | How to interpret the standard. |
| `value_type` | NVARCHAR(30) | Label | Always 'Assumed'. |

## comp.ServiceMetricDefinition

| Column | Type | Category | Purpose |
|---|---|---|---|
| `metric_code` | NVARCHAR(30) | Key | FE_CHECKOUT_WAIT, MS_REPLEN_RESPONSE, RX_WAIT. PK. |
| `dept_id` | SMALLINT | Key | Department measured by the metric (one metric per department). FK API.DimDepartment. |
| `metric_name` | NVARCHAR(100) | Assumed | Readable metric name. |
| `unit_of_measure` | NVARCHAR(20) | Assumed | minutes. |
| `target_value` | DECIMAL(8,2) | Assumed | Service threshold; a block meets target when metric_value <= target_value. FE 5, Merchandising 60, Pharmacy 20 minutes. |
| `better_direction` | NVARCHAR(10) | Assumed | 'Lower' for all three metrics. |
| `definition` | NVARCHAR(600) | Label | Precise metric definition. |
| `value_type` | NVARCHAR(30) | Label | Always 'Assumed'. |

## comp.LaborCostAssumption

| Column | Type | Category | Purpose |
|---|---|---|---|
| `store_id` | SMALLINT | Key | Warehouse. PK part, FK API.DimStore. |
| `dept_id` | SMALLINT | Key | Department. PK part, FK API.DimDepartment. |
| `base_hourly_wage` | DECIMAL(8,2) | Assumed | Mock base wage = department base x warehouse wage factor (1.00 / 1.04 / 1.02 for warehouses 1 / 2 / 4). Pharmacy is a blended pharmacist/technician rate. |
| `regular_burden_pct` | DECIMAL(5,4) | Assumed | Payroll taxes + benefits applied to regular hours (25%). |
| `loaded_regular_hourly_cost` | DECIMAL(8,2) | Derived | base_hourly_wage x (1 + regular_burden_pct). Use for regular and cross-trained flex hours. |
| `overtime_multiplier` | DECIMAL(4,2) | Assumed | Overtime pay multiplier (1.5). |
| `overtime_burden_pct` | DECIMAL(5,4) | Assumed | Payroll taxes on overtime hours (10%); benefits are not re-applied to overtime. |
| `loaded_overtime_hourly_cost` | DECIMAL(8,2) | Derived | base_hourly_wage x overtime_multiplier x (1 + overtime_burden_pct). About 32% above the loaded regular rate. |
| `weekly_overtime_threshold_hours` | DECIMAL(5,2) | Assumed | Informational (40). Data is aggregated, so overtime is modelled at the block level via max_overtime_employees rather than per person. |
| `effective_start_date` | DATE | Assumed | Rate effective date (2026-01-01). |
| `value_type` | NVARCHAR(30) | Label | Always 'Assumed'. |
| `notes` | NVARCHAR(600) | Label | Formula and caveats. |

## comp.Scenario

| Column | Type | Category | Purpose |
|---|---|---|---|
| `scenario_id` | TINYINT | Key | 0 HIST, 1 BASE, 2 PEAK, 3 DISRUPT. PK. |
| `scenario_code` | NVARCHAR(20) | Key | Short unique code. |
| `scenario_name` | NVARCHAR(100) | Label | Readable name. |
| `scenario_type` | NVARCHAR(20) | Label | 'Historical' or 'Planning'. |
| `period_start` | DATE | Label | First date covered. |
| `period_end` | DATE | Label | Last date covered. |
| `description` | NVARCHAR(1000) | Label | What the scenario represents and how to use it. |
| `value_type` | NVARCHAR(30) | Label | Historical / Forecast / Scenario-generated. |

## comp.FactShiftDemand

| Column | Type | Category | Purpose |
|---|---|---|---|
| `store_id / dept_id / day_date / shift_code` | (keys) | Key | Grain: warehouse x department x date x shift (2026-01-01 to 2026-02-11). PK. (store, dept, date) is an FK to API.FactDailyTrainingLaborOutput. |
| `day_type` | NVARCHAR(10) | Derived | Weekday/Saturday/Sunday from the calendar; with dept and shift it is the FK to comp.ShiftDefinition. |
| `is_open` | BIT | Derived | 1 if the department operated in the block (0 for closed pharmacy blocks and for the closed New Year's Day). |
| `demand_units` | DECIMAL(14,4) | Historical | Actual workload in the block. The three shifts of a day sum exactly to API.FactDailyTrainingLaborOutput.transaction_count_proxy. |
| `share_of_day` | DECIMAL(6,4) | Derived | demand_units / daily total (the observed within-day demand mix). |
| `value_type` | NVARCHAR(30) | Label | Always 'Historical'. |

## comp.FactShiftSchedule

| Column | Type | Category | Purpose |
|---|---|---|---|
| `store_id / dept_id / day_date / shift_code` | (keys) | Key | FKs to DimStore, DimDepartment, DimCalendarDay, DimShift. |
| `schedule_type` | NVARCHAR(10) | Key | 'Actual' = historical schedule as run (2026-01-01 to 02-11). 'Draft' = management's current plan for the planning week (02-12 to 02-18). PK part. |
| `scheduled_employees` | SMALLINT | Historical | Employees scheduled for the block (Actual: historical; Draft: current plan - the comparison point for recommendations). |
| `paid_hours_per_employee` | DECIMAL(4,2) | Assumed | Copied from comp.ShiftDefinition.paid_hours for convenience. |
| `scheduled_labor_hours` | DECIMAL(8,2) | Derived | scheduled_employees x paid_hours_per_employee. |
| `callout_employees` | SMALLINT | Historical | Scheduled employees who called out (Actual only; NULL for Draft). |
| `backfill_employees` | SMALLINT | Historical | Callouts replaced with someone working overtime (Actual only). |
| `worked_employees` | SMALLINT | Historical | scheduled - callouts + backfill. The staffing that actually served demand (drives the service outcome). |
| `worked_regular_employees` | SMALLINT | Historical | Worked employees paid at the regular rate (never more than available_regular_employees). |
| `worked_overtime_employees` | SMALLINT | Historical | Worked employees paid at the overtime rate (scheduled beyond regular availability, plus backfills). |
| `worked_labor_hours` | DECIMAL(8,2) | Derived | worked_employees x paid hours. |
| `worked_regular_hours` | DECIMAL(8,2) | Derived | worked_regular_employees x paid hours. |
| `worked_overtime_hours` | DECIMAL(8,2) | Derived | worked_overtime_employees x paid hours. |
| `value_type` | NVARCHAR(30) | Label | 'Historical' or 'Planned (current draft)'. |

## comp.FactShiftAvailability

| Column | Type | Category | Purpose |
|---|---|---|---|
| `scenario_id` | TINYINT | Key | 0 = historical availability; 1/2/3 = planning-week availability under BASE/PEAK/DISRUPT. PK part, FK comp.Scenario. |
| `store_id / dept_id / day_date / shift_code` | (keys) | Key | FKs to DimStore, DimDepartment, DimCalendarDay, DimShift. |
| `available_regular_employees` | SMALLINT | Historical / Forecast / Scenario-generated | Qualified employees available at straight time for the block (net of PTO, illness, weekly-hours limits). Aggregated - no employee-level records. |
| `max_overtime_employees` | SMALLINT | Historical / Forecast / Scenario-generated | Additional employees who could work the block at the overtime rate. |
| `cross_trained_flex_employees` | SMALLINT | Historical / Forecast / Scenario-generated | Employees from the partner department (Front End <-> Merchandising) qualified to cover this block at the regular rate. Using one removes one from the partner department. Always 0 for Pharmacy. |
| `available_regular_hours` | DECIMAL(8,2) | Derived | available_regular_employees x paid hours. |
| `max_overtime_hours` | DECIMAL(8,2) | Derived | max_overtime_employees x paid hours. |
| `availability_note` | NVARCHAR(300) | Label | Why availability is reduced (PTO, flu season, holiday PTO, scenario disruption). NULL when nothing notable. |
| `value_type` | NVARCHAR(30) | Label | 'Historical' (scenario 0), 'Forecast' (BASE), 'Scenario-generated' (PEAK, DISRUPT). |

## comp.FactShiftServiceLevel

| Column | Type | Category | Purpose |
|---|---|---|---|
| `store_id / dept_id / day_date / shift_code` | (keys) | Key | PK; FK to comp.FactShiftDemand. |
| `metric_code` | NVARCHAR(30) | Key | FK comp.ServiceMetricDefinition (department-specific metric). |
| `metric_value` | DECIMAL(8,1) | Historical | Simulated observed service outcome for the block, in minutes. Worse when demand is high relative to worked labor hours, and rises steeply as utilization approaches 100%. NULL when closed. |
| `target_value` | DECIMAL(8,2) | Assumed | Copied from comp.ServiceMetricDefinition. |
| `met_target` | BIT | Derived | 1 if metric_value <= target_value; NULL when closed. |
| `value_type` | NVARCHAR(30) | Label | Always 'Historical'. |

## comp.ScenarioDemandAdjustment

| Column | Type | Category | Purpose |
|---|---|---|---|
| `scenario_id / store_id / dept_id / day_date / shift_code` | (keys) | Key | One row per scenario (1-3) x planning-week block. PK; FKs to Scenario and dimensions. |
| `demand_multiplier` | DECIMAL(5,2) | Scenario-generated | Multiply YOUR baseline forecast by this value. BASE and DISRUPT = 1.00; PEAK = 1.05-1.30 on Feb 13-15 for promotion/storm traffic. |
| `adjustment_reason` | NVARCHAR(300) | Label | Driver of the multiplier. |
| `value_type` | NVARCHAR(30) | Label | 'Forecast' (BASE) or 'Scenario-generated'. |

## comp.v_ShiftHistory

| Column | Type | Category | Purpose |
|---|---|---|---|
| `(view)` | VIEW | Derived | One row per historical block joining demand, calendar/holiday/weather/promotion context, schedule, callouts, availability, cost and service. New derived column: labor_cost = worked_regular_hours x loaded regular rate + worked_overtime_hours x loaded overtime rate. Other columns are renamed copies: daily_demand_units (= transaction_count_proxy), shift_demand_units, shift_share_of_day. |

## comp.v_PlanningWeekGrid

| Column | Type | Category | Purpose |
|---|---|---|---|
| `(view)` | VIEW | Derived | One row per scenario x planning-week block: calendar/holiday context, planning-time weather and promotion features, shift definition, demand multiplier, draft schedule (draft_scheduled_employees, draft_scheduled_labor_hours), availability, cost rates and service target. Contains no demand - teams forecast it. |

## API.DimCalendarDay / API.DimHolidayDay

| Column | Type | Category | Purpose |
|---|---|---|---|
| `(planning-week rows)` | rows | Forecast | Planning week 2026-02-12 to 02-18, same column logic as the history. Includes Valentine's Day (Sat 02-14, Observance) and Presidents' Day (Mon 02-16, Federal Holiday, warehouse open). Window roles: Pre_Presidents_Day_Weekend (02-13 to 02-15), Presidents_Day_Holiday (02-16); 02-17 flagged is_post_holiday_rebound. |

## API.FactDailyFeatures

| Column | Type | Category | Purpose |
|---|---|---|---|
| `(planning-week rows)` | rows | Forecast | Planning-week features, dataset_partition = 'test' (history rows are 'train'). Same formulas as the history; markdown fields use week-6 sales as the planning basis; temperature is the planning-time forecast. Returned by API.v_ebm_test_features_model_only. |

## model.ModelRun

| Column | Type | Category | Purpose |
|---|---|---|---|
| `(benchmark run)` | row | Forecast | model_run_id 2026021101: Naive Same-Weekday Benchmark. |

## src.FactDailyPrediction

| Column | Type | Category | Purpose |
|---|---|---|---|
| `(planning-week rows)` | rows | Forecast | model_run_id 2026021101: average of the same weekday in weeks 3-6 for every predicted_* column, banded with API.LaborBandRule. Deliberately ignores holidays, promotions and weather - teams should beat it. |
