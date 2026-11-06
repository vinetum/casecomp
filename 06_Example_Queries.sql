/*
    LaunchProject - Texas MISA Fall 2026 Case Competition
    Script 06 of 06: example queries (read-only)

    These are STARTER queries. They show how the tables fit together; they are deliberately naive where a
    team is expected to do better (forecast method, target utilization, holiday/promotion effects, use of
    overtime vs. cross-training).

    Parameters are written as a one-row CTE ("params") instead of DECLARE so each query runs on its own.

    Q1  Demand by warehouse, department, date and shift (history), plus a starter shift-level forecast
    Q2  Staffing gap (historical worked staff vs. staff required at a chosen utilization)
    Q3  Labor cost by warehouse, department and week
    Q4  Service-level performance, and service vs. utilization (the cost/service trade-off curve)
    Q5  Recommended staffing for the planning week by scenario, with cost and comparison to the draft schedule
*/
USE [LaunchProject];
GO

/* =====================================================================================================
   Q1a. Historical demand by warehouse, department, date and shift
===================================================================================================== */
SELECT [store_id], [department_group], [day_date], [day_name], [holiday_window_role], [shift_code],
       [shift_start_time], [shift_end_time], [is_open], [daily_demand_units], [shift_demand_units], [shift_share_of_day]
FROM [comp].[v_ShiftHistory]
ORDER BY [store_id], [dept_id], [day_date], [shift_sequence];
GO

/* Q1b. Typical demand profile: average shift demand by weekday and shift, normal days only */
SELECT [store_id], [department_group], [day_of_week], [day_name], [shift_code],
       CAST(AVG([shift_demand_units]) AS DECIMAL(10,2)) AS [avg_shift_demand_units],
       CAST(MIN([shift_demand_units]) AS DECIMAL(10,2)) AS [min_shift_demand_units],
       CAST(MAX([shift_demand_units]) AS DECIMAL(10,2)) AS [max_shift_demand_units]
FROM [comp].[v_ShiftHistory]
WHERE [is_open] = 1 AND [holiday_window_role] = 'Normal'
GROUP BY [store_id], [dept_id], [department_group], [day_of_week], [day_name], [shift_code], [shift_sequence]
ORDER BY [store_id], [dept_id], [day_of_week], [shift_sequence];
GO

/* Q1c. STARTER planning-week forecast by shift = naive daily benchmark x average historical shift share x scenario multiplier.
        Weakness on purpose: the naive daily benchmark ignores Presidents' Day / Valentine's Day. Teams should improve it. */
WITH share AS (
    SELECT [dept_id], [day_type], [shift_code], AVG([share_of_day]) AS [avg_share]
    FROM [comp].[FactShiftDemand]
    WHERE [is_open] = 1
    GROUP BY [dept_id], [day_type], [shift_code]
)
SELECT g.[scenario_code], g.[store_id], g.[department_group], g.[day_date], g.[day_name], g.[holiday_window_role], g.[shift_code],
       p.[predicted_transaction_count_proxy] AS [naive_daily_forecast_units],
       CAST(COALESCE(sh.[avg_share], 0) AS DECIMAL(6,4)) AS [avg_shift_share],
       g.[demand_multiplier],
       CAST(p.[predicted_transaction_count_proxy] * COALESCE(sh.[avg_share], 0) * g.[demand_multiplier] AS DECIMAL(12,4)) AS [forecast_shift_demand_units]
FROM [comp].[v_PlanningWeekGrid] g
INNER JOIN [src].[FactDailyPrediction] p
    ON p.[model_run_id] = 2026021101 AND p.[store_id] = g.[store_id] AND p.[dept_id] = g.[dept_id] AND p.[day_date] = g.[day_date]
LEFT JOIN share sh ON sh.[dept_id] = g.[dept_id] AND sh.[day_type] = g.[day_type] AND sh.[shift_code] = g.[shift_code]
ORDER BY g.[scenario_id], g.[store_id], g.[dept_id], g.[day_date], g.[shift_code];
GO

/* =====================================================================================================
   Q2. Staffing gap (history): employees actually worked vs. employees required at a target utilization.
       required = MAX(min_staff, CEILING(demand x labor-hours-per-unit / (paid hours x target utilization)))
       target_util = 0.85 is a STARTING ASSUMPTION - use Q4b to choose your own value per department.
===================================================================================================== */
WITH params AS (SELECT CAST(0.85 AS DECIMAL(4,2)) AS [target_util]),
req AS (
    SELECT v.[store_id], v.[department_group], v.[dept_id], v.[day_date], v.[day_name], v.[holiday_window_role], v.[shift_code],
           v.[shift_demand_units], v.[scheduled_employees], v.[worked_employees], v.[min_staff], v.[metric_value], v.[met_target],
           CASE WHEN v.[is_open] = 0 THEN 0 ELSE
               CAST(CEILING(v.[shift_demand_units] * ls.[labor_hours_per_workload_unit] / (v.[paid_hours] * pr.[target_util])) AS INT)
           END AS [raw_required]
    FROM [comp].[v_ShiftHistory] v
    INNER JOIN [comp].[LaborStandard] ls ON ls.[dept_id] = v.[dept_id]
    CROSS JOIN params pr
)
SELECT [store_id], [department_group], [day_date], [day_name], [holiday_window_role], [shift_code], [shift_demand_units],
       [scheduled_employees], [worked_employees],
       CASE WHEN [raw_required] > 0 AND [raw_required] < [min_staff] THEN [min_staff] ELSE [raw_required] END AS [required_employees],
       [worked_employees] - CASE WHEN [raw_required] > 0 AND [raw_required] < [min_staff] THEN [min_staff] ELSE [raw_required] END AS [staffing_gap],
       CASE WHEN [worked_employees] - CASE WHEN [raw_required] > 0 AND [raw_required] < [min_staff] THEN [min_staff] ELSE [raw_required] END < 0 THEN 'Understaffed'
            WHEN [worked_employees] - CASE WHEN [raw_required] > 0 AND [raw_required] < [min_staff] THEN [min_staff] ELSE [raw_required] END > 1 THEN 'Overstaffed'
            ELSE 'Aligned' END AS [gap_status],
       [metric_value], [met_target]
FROM req
ORDER BY [store_id], [dept_id], [day_date], [shift_code];
GO

/* Q2b. Gap summary by warehouse, department and shift (where are hours systematically too high or too low?) */
WITH params AS (SELECT CAST(0.85 AS DECIMAL(4,2)) AS [target_util]),
req AS (
    SELECT v.[store_id], v.[dept_id], v.[department_group], v.[shift_code], v.[day_type], v.[worked_employees], v.[min_staff], v.[met_target],
           CAST(CEILING(v.[shift_demand_units] * ls.[labor_hours_per_workload_unit] / (v.[paid_hours] * pr.[target_util])) AS INT) AS [raw_required]
    FROM [comp].[v_ShiftHistory] v
    INNER JOIN [comp].[LaborStandard] ls ON ls.[dept_id] = v.[dept_id]
    CROSS JOIN params pr
    WHERE v.[is_open] = 1
)
SELECT [store_id], [department_group], [day_type], [shift_code], COUNT(*) AS [blocks],
       CAST(AVG(1.0 * ([worked_employees] - CASE WHEN [raw_required] < [min_staff] THEN [min_staff] ELSE [raw_required] END)) AS DECIMAL(6,2)) AS [avg_gap_employees],
       SUM(CASE WHEN [worked_employees] < CASE WHEN [raw_required] < [min_staff] THEN [min_staff] ELSE [raw_required] END THEN 1 ELSE 0 END) AS [understaffed_blocks],
       CAST(100.0 * AVG(CAST([met_target] AS FLOAT)) AS DECIMAL(5,1)) AS [pct_met_target]
FROM req
GROUP BY [store_id], [dept_id], [department_group], [day_type], [shift_code]
ORDER BY [store_id], [dept_id], [day_type], [shift_code];
GO

/* =====================================================================================================
   Q3. Labor cost by warehouse, department and week (regular vs. overtime, cost per workload unit)
===================================================================================================== */
SELECT v.[store_id], v.[department_group], v.[week_start_date],
       SUM(v.[worked_regular_hours])  AS [regular_hours],
       SUM(v.[worked_overtime_hours]) AS [overtime_hours],
       CAST(SUM(v.[worked_regular_hours] * lc.[loaded_regular_hourly_cost]) AS DECIMAL(12,2))   AS [regular_cost],
       CAST(SUM(v.[worked_overtime_hours] * lc.[loaded_overtime_hourly_cost]) AS DECIMAL(12,2)) AS [overtime_cost],
       CAST(SUM(v.[labor_cost]) AS DECIMAL(12,2)) AS [total_labor_cost],
       CAST(SUM(v.[labor_cost]) / NULLIF(SUM(v.[shift_demand_units]), 0) AS DECIMAL(10,2)) AS [cost_per_workload_unit],
       CAST(100.0 * SUM(v.[worked_overtime_hours]) / NULLIF(SUM(v.[worked_labor_hours]), 0) AS DECIMAL(5,1)) AS [overtime_pct_of_hours],
       SUM(v.[callout_employees]) AS [callouts]
FROM [comp].[v_ShiftHistory] v
INNER JOIN [comp].[LaborCostAssumption] lc ON lc.[store_id] = v.[store_id] AND lc.[dept_id] = v.[dept_id]
GROUP BY v.[store_id], v.[dept_id], v.[department_group], v.[week_start_date]
ORDER BY v.[store_id], v.[dept_id], v.[week_start_date];
GO

/* =====================================================================================================
   Q4a. Service-level performance by warehouse, department, day type and shift
===================================================================================================== */
SELECT v.[store_id], v.[department_group], v.[metric_code], v.[target_value], v.[day_type], v.[shift_code],
       COUNT(v.[metric_value]) AS [open_blocks],
       CAST(AVG(v.[metric_value]) AS DECIMAL(8,1)) AS [avg_metric_value],
       CAST(MAX(v.[metric_value]) AS DECIMAL(8,1)) AS [worst_metric_value],
       CAST(100.0 * AVG(CAST(v.[met_target] AS FLOAT)) AS DECIMAL(5,1)) AS [pct_blocks_meeting_target]
FROM [comp].[v_ShiftHistory] v
WHERE v.[is_open] = 1
GROUP BY v.[store_id], v.[dept_id], v.[department_group], v.[metric_code], v.[target_value], v.[day_type], v.[shift_code]
ORDER BY v.[store_id], v.[dept_id], v.[day_type], v.[shift_code];
GO

/* Q4b. Service vs. utilization. utilization = workload hours needed / labor hours worked.
        Shows where service starts to break down - use it to choose a target utilization per department. */
WITH u AS (
    SELECT v.[department_group], v.[dept_id], v.[metric_value], v.[target_value], v.[met_target],
           v.[shift_demand_units] * ls.[labor_hours_per_workload_unit] / v.[worked_labor_hours] AS [utilization]
    FROM [comp].[v_ShiftHistory] v
    INNER JOIN [comp].[LaborStandard] ls ON ls.[dept_id] = v.[dept_id]
    WHERE v.[is_open] = 1
)
SELECT [department_group],
       CAST(FLOOR([utilization] * 20) / 20.0 AS DECIMAL(4,2)) AS [utilization_band_start],
       COUNT(*) AS [blocks],
       CAST(AVG([metric_value]) AS DECIMAL(8,1)) AS [avg_metric_value],
       MAX([target_value]) AS [target_value],
       CAST(100.0 * AVG(CAST([met_target] AS FLOAT)) AS DECIMAL(5,1)) AS [pct_meeting_target]
FROM u
GROUP BY [dept_id], [department_group], CAST(FLOOR([utilization] * 20) / 20.0 AS DECIMAL(4,2))
ORDER BY [dept_id], [utilization_band_start];
GO

/* =====================================================================================================
   Q5. STARTER recommended staffing for the planning week, by scenario.
       Forecast (Q1c) -> required employees at target utilization -> fit to availability
       (regular first, then cross-trained flex, then overtime) -> cost -> compare with the draft schedule.
       Known simplifications teams should challenge: naive forecast, one target utilization for all depts,
       no expected callout buffer, flex borrowed without reducing the other department.
===================================================================================================== */
WITH params AS (SELECT CAST(0.85 AS DECIMAL(4,2)) AS [target_util]),
share AS (
    SELECT [dept_id], [day_type], [shift_code], AVG([share_of_day]) AS [avg_share]
    FROM [comp].[FactShiftDemand] WHERE [is_open] = 1
    GROUP BY [dept_id], [day_type], [shift_code]
),
fc AS (
    SELECT g.*, ls.[labor_hours_per_workload_unit],
           p.[predicted_transaction_count_proxy] * COALESCE(sh.[avg_share], 0) * g.[demand_multiplier] AS [forecast_units]
    FROM [comp].[v_PlanningWeekGrid] g
    INNER JOIN [src].[FactDailyPrediction] p
        ON p.[model_run_id] = 2026021101 AND p.[store_id] = g.[store_id] AND p.[dept_id] = g.[dept_id] AND p.[day_date] = g.[day_date]
    INNER JOIN [comp].[LaborStandard] ls ON ls.[dept_id] = g.[dept_id]
    LEFT JOIN share sh ON sh.[dept_id] = g.[dept_id] AND sh.[day_type] = g.[day_type] AND sh.[shift_code] = g.[shift_code]
),
req AS (
    SELECT fc.*,
           fc.[available_regular_employees] + fc.[cross_trained_flex_employees] + fc.[max_overtime_employees] AS [capacity],
           CASE WHEN fc.[is_open] = 0 THEN 0 ELSE
               CAST(CEILING(fc.[forecast_units] * fc.[labor_hours_per_workload_unit] / (fc.[paid_hours] * pr.[target_util])) AS INT)
           END AS [raw_required]
    FROM fc CROSS JOIN params pr
),
rec AS (
    SELECT req.*,
           CASE WHEN [raw_required] > 0 AND [raw_required] < [min_staff] THEN [min_staff] ELSE [raw_required] END AS [required_employees]
    FROM req
),
fit AS (
    SELECT rec.*,
           CASE WHEN [required_employees] > [capacity] THEN [capacity] ELSE [required_employees] END AS [recommended_employees],
           CASE WHEN [draft_scheduled_employees] > [capacity] THEN [capacity] ELSE [draft_scheduled_employees] END AS [draft_effective]
    FROM rec
),
mix AS (
    SELECT fit.*,
           CASE WHEN [recommended_employees] > [available_regular_employees] THEN [available_regular_employees] ELSE [recommended_employees] END AS [rec_regular],
           CASE WHEN [draft_effective] > [available_regular_employees] THEN [available_regular_employees] ELSE [draft_effective] END AS [draft_regular]
    FROM fit
),
mix2 AS (
    SELECT mix.*,
           CASE WHEN [recommended_employees] - [rec_regular] > [cross_trained_flex_employees] THEN [cross_trained_flex_employees]
                ELSE [recommended_employees] - [rec_regular] END AS [rec_flex],
           CASE WHEN [draft_effective] - [draft_regular] > [cross_trained_flex_employees] THEN [cross_trained_flex_employees]
                ELSE [draft_effective] - [draft_regular] END AS [draft_flex]
    FROM mix
)
SELECT [scenario_code], [store_id], [department_group], [day_date], [day_name], [shift_code],
       CAST([forecast_units] AS DECIMAL(10,2)) AS [forecast_units],
       [required_employees], [capacity], [recommended_employees],
       [rec_regular] AS [rec_regular_employees], [rec_flex] AS [rec_flex_employees],
       [recommended_employees] - [rec_regular] - [rec_flex] AS [rec_overtime_employees],
       CASE WHEN [required_employees] > [capacity] THEN 'Capacity shortfall' ELSE '' END AS [warning],
       [draft_scheduled_employees],
       [recommended_employees] - [draft_scheduled_employees] AS [change_vs_draft],
       CAST(([rec_regular] + [rec_flex]) * [paid_hours] * [loaded_regular_hourly_cost]
          + ([recommended_employees] - [rec_regular] - [rec_flex]) * [paid_hours] * [loaded_overtime_hourly_cost] AS DECIMAL(12,2)) AS [recommended_cost],
       CASE WHEN [draft_scheduled_employees] > [capacity] THEN 'Draft exceeds capacity' ELSE '' END AS [draft_warning],
       CAST(([draft_regular] + [draft_flex]) * [paid_hours] * [loaded_regular_hourly_cost]
          + ([draft_effective] - [draft_regular] - [draft_flex]) * [paid_hours] * [loaded_overtime_hourly_cost] AS DECIMAL(12,2)) AS [draft_cost],
       [metric_code], [service_target_value]
FROM mix2
ORDER BY [scenario_id], [store_id], [dept_id], [day_date], [shift_code];
GO

/* Q5b. Scenario summary of the starter recommendation vs. the draft (hours and cost) */
WITH params AS (SELECT CAST(0.85 AS DECIMAL(4,2)) AS [target_util]),
share AS (
    SELECT [dept_id], [day_type], [shift_code], AVG([share_of_day]) AS [avg_share]
    FROM [comp].[FactShiftDemand] WHERE [is_open] = 1
    GROUP BY [dept_id], [day_type], [shift_code]
),
req AS (
    SELECT g.[scenario_id], g.[scenario_code], g.[dept_id], g.[department_group], g.[paid_hours], g.[min_staff], g.[is_open],
           g.[draft_scheduled_employees],
           g.[available_regular_employees] + g.[cross_trained_flex_employees] + g.[max_overtime_employees] AS [capacity],
           CASE WHEN g.[is_open] = 0 THEN 0 ELSE CAST(CEILING(p.[predicted_transaction_count_proxy] * COALESCE(sh.[avg_share], 0) * g.[demand_multiplier]
                * ls.[labor_hours_per_workload_unit] / (g.[paid_hours] * pr.[target_util])) AS INT) END AS [raw_required]
    FROM [comp].[v_PlanningWeekGrid] g
    INNER JOIN [src].[FactDailyPrediction] p
        ON p.[model_run_id] = 2026021101 AND p.[store_id] = g.[store_id] AND p.[dept_id] = g.[dept_id] AND p.[day_date] = g.[day_date]
    INNER JOIN [comp].[LaborStandard] ls ON ls.[dept_id] = g.[dept_id]
    LEFT JOIN share sh ON sh.[dept_id] = g.[dept_id] AND sh.[day_type] = g.[day_type] AND sh.[shift_code] = g.[shift_code]
    CROSS JOIN params pr
),
rec AS (
    SELECT req.*,
           CASE WHEN (CASE WHEN [raw_required] > 0 AND [raw_required] < [min_staff] THEN [min_staff] ELSE [raw_required] END) > [capacity]
                THEN [capacity] ELSE (CASE WHEN [raw_required] > 0 AND [raw_required] < [min_staff] THEN [min_staff] ELSE [raw_required] END) END AS [recommended_employees]
    FROM req
)
SELECT [scenario_code], [department_group],
       SUM([draft_scheduled_employees] * [paid_hours]) AS [draft_labor_hours],
       SUM([recommended_employees] * [paid_hours])     AS [recommended_labor_hours],
       SUM(CASE WHEN [draft_scheduled_employees] > [capacity] THEN 1 ELSE 0 END) AS [draft_blocks_over_capacity]
FROM rec
GROUP BY [scenario_id], [scenario_code], [dept_id], [department_group]
ORDER BY [scenario_id], [dept_id];
GO
