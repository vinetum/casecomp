/*
    LaunchProject - Texas MISA Fall 2026 Case Competition
    Script 05 of 06: validation checks. Read-only. Run after 01-04.

    Every check returns one row: check_id, area, check_name, expected, actual, status (PASS / FAIL / INFO).
    INFO rows describe intentional features of the case (e.g. the draft schedule does not fit the DISRUPT scenario).
*/
SET NOCOUNT ON;
GO
USE [LaunchProject];
GO

SELECT * FROM (

/* ---------------- Completeness ---------------- */
SELECT 'C01' AS check_id, 'Completeness' AS area, 'Historical shift-demand grid = 3 warehouses x 3 depts x 42 days x 3 shifts' AS check_name,
       '1134' AS expected, CAST(x AS VARCHAR(50)) AS actual, CASE WHEN x = 1134 THEN 'PASS' ELSE 'FAIL' END AS status
FROM (SELECT COUNT(*) AS x FROM [comp].[FactShiftDemand]) q
UNION ALL
SELECT 'C02', 'Completeness', 'Every daily demand row has exactly 3 shift rows', '0 days missing shifts', CAST(x AS VARCHAR(50)),
       CASE WHEN x = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) AS x FROM [API].[FactDailyTrainingLaborOutput] tl
      WHERE (SELECT COUNT(*) FROM [comp].[FactShiftDemand] d
             WHERE d.[store_id] = tl.[store_id] AND d.[dept_id] = tl.[dept_id] AND d.[day_date] = tl.[day_date]) <> 3) q
UNION ALL
SELECT 'C03', 'Completeness', 'Schedules: 1134 Actual + 189 Draft rows', '1134 / 189', CONCAT(CAST(a AS VARCHAR(20)), ' / ', CAST(b AS VARCHAR(20))),
       CASE WHEN a = 1134 AND b = 189 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT SUM(CASE WHEN [schedule_type] = 'Actual' THEN 1 ELSE 0 END) AS a,
             SUM(CASE WHEN [schedule_type] = 'Draft' THEN 1 ELSE 0 END) AS b FROM [comp].[FactShiftSchedule]) q
UNION ALL
SELECT 'C04', 'Completeness', 'Availability: 1134 HIST rows + 189 rows for each of BASE/PEAK/DISRUPT', '1134/189/189/189',
       CONCAT(CAST(h AS VARCHAR(10)), '/', CAST(b AS VARCHAR(10)), '/', CAST(p AS VARCHAR(10)), '/', CAST(d AS VARCHAR(10))),
       CASE WHEN h = 1134 AND b = 189 AND p = 189 AND d = 189 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT SUM(CASE WHEN [scenario_id] = 0 THEN 1 ELSE 0 END) AS h, SUM(CASE WHEN [scenario_id] = 1 THEN 1 ELSE 0 END) AS b,
             SUM(CASE WHEN [scenario_id] = 2 THEN 1 ELSE 0 END) AS p, SUM(CASE WHEN [scenario_id] = 3 THEN 1 ELSE 0 END) AS d
      FROM [comp].[FactShiftAvailability]) q
UNION ALL
SELECT 'C05', 'Completeness', 'Service rows = 1134; scenario demand adjustments = 567', '1134 / 567',
       CONCAT(CAST(a AS VARCHAR(20)), ' / ', CAST(b AS VARCHAR(20))), CASE WHEN a = 1134 AND b = 567 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT (SELECT COUNT(*) FROM [comp].[FactShiftServiceLevel]) AS a, (SELECT COUNT(*) FROM [comp].[ScenarioDemandAdjustment]) AS b) q
UNION ALL
SELECT 'C06', 'Completeness', 'Reference tables: 3 shifts, 27 shift definitions, 3 standards, 3 metrics, 9 cost rows, 4 scenarios',
       '3/27/3/3/9/4',
       CONCAT(CAST(a AS VARCHAR(5)), '/', CAST(b AS VARCHAR(5)), '/', CAST(c AS VARCHAR(5)), '/', CAST(d AS VARCHAR(5)), '/', CAST(e AS VARCHAR(5)), '/', CAST(f AS VARCHAR(5))),
       CASE WHEN a = 3 AND b = 27 AND c = 3 AND d = 3 AND e = 9 AND f = 4 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT (SELECT COUNT(*) FROM [comp].[DimShift]) AS a, (SELECT COUNT(*) FROM [comp].[ShiftDefinition]) AS b,
             (SELECT COUNT(*) FROM [comp].[LaborStandard]) AS c, (SELECT COUNT(*) FROM [comp].[ServiceMetricDefinition]) AS d,
             (SELECT COUNT(*) FROM [comp].[LaborCostAssumption]) AS e, (SELECT COUNT(*) FROM [comp].[Scenario]) AS f) q
UNION ALL
SELECT 'C07', 'Completeness', 'Planning week added to calendar/holiday dims (49 days each) and features (63 test rows)', '49/49/63',
       CONCAT(CAST(a AS VARCHAR(5)), '/', CAST(b AS VARCHAR(5)), '/', CAST(c AS VARCHAR(5))),
       CASE WHEN a = 49 AND b = 49 AND c = 63 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT (SELECT COUNT(*) FROM [API].[DimCalendarDay]) AS a, (SELECT COUNT(*) FROM [API].[DimHolidayDay]) AS b,
             (SELECT COUNT(*) FROM [API].[FactDailyFeatures] WHERE [dataset_partition] = 'test') AS c) q
UNION ALL
SELECT 'C08', 'Completeness', 'EBM feature views return train = 378 and test = 63 rows; shift views 1134 / 567', '378/63/1134/567',
       CONCAT(CAST(a AS VARCHAR(5)), '/', CAST(b AS VARCHAR(5)), '/', CAST(c AS VARCHAR(5)), '/', CAST(d AS VARCHAR(5))),
       CASE WHEN a = 378 AND b = 63 AND c = 1134 AND d = 567 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT (SELECT COUNT(*) FROM [API].[v_ebm_train_features_model_only]) AS a, (SELECT COUNT(*) FROM [API].[v_ebm_test_features_model_only]) AS b,
             (SELECT COUNT(*) FROM [comp].[v_ShiftHistory]) AS c, (SELECT COUNT(*) FROM [comp].[v_PlanningWeekGrid]) AS d) q
UNION ALL
SELECT 'C09', 'Completeness', 'Naive benchmark forecast rows for planning week (model_run_id 2026021101)', '63', CAST(x AS VARCHAR(10)),
       CASE WHEN x = 63 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) AS x FROM [src].[FactDailyPrediction] WHERE [model_run_id] = 2026021101) q

/* ---------------- Demand consistency ---------------- */
UNION ALL
SELECT 'D01', 'Demand', 'Shift demand sums to daily transaction_count_proxy (tolerance 0.001)', '0 mismatched days', CAST(x AS VARCHAR(10)),
       CASE WHEN x = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) AS x FROM (
        SELECT tl.[store_id], tl.[dept_id], tl.[day_date], MAX(tl.[transaction_count_proxy]) AS daily, SUM(d.[demand_units]) AS shifts
        FROM [API].[FactDailyTrainingLaborOutput] tl
        INNER JOIN [comp].[FactShiftDemand] d ON d.[store_id] = tl.[store_id] AND d.[dept_id] = tl.[dept_id] AND d.[day_date] = tl.[day_date]
        GROUP BY tl.[store_id], tl.[dept_id], tl.[day_date]) z
      WHERE ABS(z.daily - z.shifts) > 0.001) q
UNION ALL
SELECT 'D02', 'Demand', 'is_open matches ShiftDefinition and warehouse closures', '0 violations', CAST(x AS VARCHAR(10)),
       CASE WHEN x = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) AS x FROM [comp].[FactShiftDemand] d
      INNER JOIN [comp].[ShiftDefinition] sd ON sd.[dept_id] = d.[dept_id] AND sd.[day_type] = d.[day_type] AND sd.[shift_code] = d.[shift_code]
      INNER JOIN [API].[DimHolidayDay] h ON h.[day_date] = d.[day_date]
      WHERE d.[is_open] <> CASE WHEN h.[is_costco_closed] = 1 THEN 0 ELSE sd.[is_open] END) q
UNION ALL
SELECT 'D03', 'Demand', 'day_type matches calendar day_of_week (6 = Saturday, 7 = Sunday)', '0 violations', CAST(x AS VARCHAR(10)),
       CASE WHEN x = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) AS x FROM [comp].[FactShiftDemand] d INNER JOIN [API].[DimCalendarDay] c ON c.[day_date] = d.[day_date]
      WHERE d.[day_type] <> CASE c.[day_of_week] WHEN 6 THEN 'Saturday' WHEN 7 THEN 'Sunday' ELSE 'Weekday' END) q
UNION ALL
SELECT 'D04', 'Demand', 'Closed blocks have zero demand, zero staff, no service value', '0 violations', CAST(x AS VARCHAR(10)),
       CASE WHEN x = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) AS x FROM [comp].[v_ShiftHistory]
      WHERE [is_open] = 0 AND ([shift_demand_units] <> 0 OR [scheduled_employees] <> 0 OR [metric_value] IS NOT NULL)) q
UNION ALL
SELECT 'D05', 'Demand', 'No planning-week actual demand in any student-facing table (leakage check)', 'max date 2026-02-11',
       CAST(CASE WHEN a > b THEN a ELSE b END AS VARCHAR(20)), CASE WHEN a <= '2026-02-11' AND b <= '2026-02-11' THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT (SELECT MAX([day_date]) FROM [comp].[FactShiftDemand]) AS a, (SELECT MAX([day_date]) FROM [API].[FactDailyTrainingLaborOutput]) AS b) q

/* ---------------- Staffing / availability consistency ---------------- */
UNION ALL
SELECT 'S01', 'Staffing', 'worked = scheduled - callouts + backfill; regular + overtime = worked', '0 violations', CAST(x AS VARCHAR(10)),
       CASE WHEN x = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) AS x FROM [comp].[FactShiftSchedule] WHERE [schedule_type] = 'Actual'
      AND ([worked_employees] <> [scheduled_employees] - [callout_employees] + [backfill_employees]
           OR [worked_regular_employees] + [worked_overtime_employees] <> [worked_employees])) q
UNION ALL
SELECT 'S02', 'Staffing', 'Labor hours = employees x paid hours (scheduled, worked, regular, overtime, availability)', '0 violations',
       CAST(x AS VARCHAR(10)), CASE WHEN x = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT
        (SELECT COUNT(*) FROM [comp].[FactShiftSchedule] s
         WHERE s.[scheduled_labor_hours] <> s.[scheduled_employees] * s.[paid_hours_per_employee]
            OR (s.[schedule_type] = 'Actual' AND (s.[worked_labor_hours] <> s.[worked_employees] * s.[paid_hours_per_employee]
                OR s.[worked_regular_hours] <> s.[worked_regular_employees] * s.[paid_hours_per_employee]
                OR s.[worked_overtime_hours] <> s.[worked_overtime_employees] * s.[paid_hours_per_employee])))
      + (SELECT COUNT(*) FROM [comp].[FactShiftAvailability] a
         INNER JOIN [API].[DimCalendarDay] c ON c.[day_date] = a.[day_date]
         INNER JOIN [comp].[ShiftDefinition] sd ON sd.[dept_id] = a.[dept_id] AND sd.[shift_code] = a.[shift_code]
                AND sd.[day_type] = CASE c.[day_of_week] WHEN 6 THEN 'Saturday' WHEN 7 THEN 'Sunday' ELSE 'Weekday' END
         WHERE a.[available_regular_hours] <> a.[available_regular_employees] * sd.[paid_hours]
            OR a.[max_overtime_hours] <> a.[max_overtime_employees] * sd.[paid_hours]) AS x) q
UNION ALL
SELECT 'S03', 'Staffing', 'Paid hours on schedules match ShiftDefinition', '0 violations', CAST(x AS VARCHAR(10)),
       CASE WHEN x = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) AS x FROM [comp].[FactShiftSchedule] s
      INNER JOIN [API].[DimCalendarDay] c ON c.[day_date] = s.[day_date]
      INNER JOIN [comp].[ShiftDefinition] sd ON sd.[dept_id] = s.[dept_id] AND sd.[shift_code] = s.[shift_code]
             AND sd.[day_type] = CASE c.[day_of_week] WHEN 6 THEN 'Saturday' WHEN 7 THEN 'Sunday' ELSE 'Weekday' END
      WHERE s.[paid_hours_per_employee] <> sd.[paid_hours]) q
UNION ALL
SELECT 'S04', 'Staffing', 'Historical: scheduled <= regular + OT capacity; regular worked <= regular available; OT worked <= OT capacity',
       '0 violations', CAST(x AS VARCHAR(10)), CASE WHEN x = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) AS x FROM [comp].[v_ShiftHistory]
      WHERE [scheduled_employees] > [available_regular_employees] + [max_overtime_employees]
         OR [worked_regular_employees] > [available_regular_employees]
         OR [worked_overtime_employees] > [max_overtime_employees]) q
UNION ALL
SELECT 'S05', 'Staffing', 'Every open historical block has at least one worker and meets minimum-staff on the schedule', '0 violations',
       CAST(x AS VARCHAR(10)), CASE WHEN x = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) AS x FROM [comp].[v_ShiftHistory] WHERE [is_open] = 1 AND ([worked_employees] < 1 OR [scheduled_employees] < [min_staff])) q
UNION ALL
SELECT 'S06', 'Staffing', 'Draft schedule fits BASE capacity (regular + OT + flex) and covers minimum staff', '0 violations',
       CAST(x AS VARCHAR(10)), CASE WHEN x = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) AS x FROM [comp].[v_PlanningWeekGrid] WHERE [scenario_code] = 'BASE' AND [is_open] = 1
      AND ([draft_scheduled_employees] > [available_regular_employees] + [max_overtime_employees] + [cross_trained_flex_employees]
           OR [draft_scheduled_employees] < [min_staff])) q
UNION ALL
SELECT 'S07', 'Staffing', 'INFO (intended): draft blocks that exceed DISRUPT capacity - teams must re-plan these', '> 0', CAST(x AS VARCHAR(10)),
       CASE WHEN x > 0 THEN 'INFO' ELSE 'FAIL' END
FROM (SELECT COUNT(*) AS x FROM [comp].[v_PlanningWeekGrid] WHERE [scenario_code] = 'DISRUPT'
      AND [draft_scheduled_employees] > [available_regular_employees] + [max_overtime_employees] + [cross_trained_flex_employees]) q
UNION ALL
SELECT 'S08', 'Staffing', 'Pharmacy has no cross-trained flex (licensure); closed blocks have zero availability', '0 violations',
       CAST(x AS VARCHAR(10)), CASE WHEN x = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT (SELECT COUNT(*) FROM [comp].[FactShiftAvailability] WHERE [dept_id] = 95 AND [cross_trained_flex_employees] <> 0)
           + (SELECT COUNT(*) FROM [comp].[v_PlanningWeekGrid] WHERE [is_open] = 0 AND [available_regular_employees] + [max_overtime_employees] > 0) AS x) q

/* ---------------- Cost ---------------- */
UNION ALL
SELECT 'K01', 'Cost', 'Loaded rates follow documented formulas and OT rate > regular rate', '0 violations', CAST(x AS VARCHAR(10)),
       CASE WHEN x = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) AS x FROM [comp].[LaborCostAssumption]
      WHERE ABS([loaded_regular_hourly_cost] - [base_hourly_wage] * (1 + [regular_burden_pct])) > 0.01
         OR ABS([loaded_overtime_hourly_cost] - [base_hourly_wage] * [overtime_multiplier] * (1 + [overtime_burden_pct])) > 0.01
         OR [loaded_overtime_hourly_cost] <= [loaded_regular_hourly_cost]) q
UNION ALL
SELECT 'K02', 'Cost', 'INFO: total simulated historical labor cost (6 weeks, 3 warehouses)', 'informational',
       CAST(CAST(x AS DECIMAL(14,2)) AS VARCHAR(30)), 'INFO'
FROM (SELECT SUM([labor_cost]) AS x FROM [comp].[v_ShiftHistory]) q

/* ---------------- Service ---------------- */
UNION ALL
SELECT 'V01', 'Service', 'Open blocks have a metric value; met_target consistent with target; metric code matches dept', '0 violations',
       CAST(x AS VARCHAR(10)), CASE WHEN x = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) AS x FROM [comp].[FactShiftServiceLevel] sl
      INNER JOIN [comp].[FactShiftDemand] d ON d.[store_id] = sl.[store_id] AND d.[dept_id] = sl.[dept_id] AND d.[day_date] = sl.[day_date] AND d.[shift_code] = sl.[shift_code]
      INNER JOIN [comp].[ServiceMetricDefinition] m ON m.[metric_code] = sl.[metric_code]
      WHERE (d.[is_open] = 1 AND sl.[metric_value] IS NULL)
         OR m.[dept_id] <> sl.[dept_id] OR sl.[target_value] <> m.[target_value]
         OR (sl.[metric_value] IS NOT NULL AND sl.[met_target] <> CASE WHEN sl.[metric_value] <= sl.[target_value] THEN 1 ELSE 0 END)) q
UNION ALL
SELECT 'V02', 'Service', 'Direction: busiest-utilization quartile has worse service (metric/target) than least-busy quartile, every dept',
       'q4 > 1.5 x q1 in 3 of 3 depts', CONCAT(CAST(x AS VARCHAR(10)), ' of 3'), CASE WHEN x = 3 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT SUM(CASE WHEN q4 > 1.5 * q1 THEN 1 ELSE 0 END) AS x FROM (
        SELECT [dept_id],
               AVG(CASE WHEN qt = 1 THEN ratio END) AS q1, AVG(CASE WHEN qt = 4 THEN ratio END) AS q4
        FROM (SELECT v.[dept_id], v.[metric_value] / v.[target_value] AS ratio,
                     NTILE(4) OVER (PARTITION BY v.[dept_id]
                                    ORDER BY v.[shift_demand_units] * ls.[labor_hours_per_workload_unit] / v.[worked_labor_hours]) AS qt
              FROM [comp].[v_ShiftHistory] v
              INNER JOIN [comp].[LaborStandard] ls ON ls.[dept_id] = v.[dept_id]
              WHERE v.[is_open] = 1) z
        GROUP BY [dept_id]) y) q
UNION ALL
SELECT 'V03', 'Service', 'INFO: share of open historical blocks meeting target (should be neither ~0% nor ~100%)', '60%-90%',
       CONCAT(CAST(CAST(100.0 * x AS DECIMAL(5,1)) AS VARCHAR(10)), '%'), CASE WHEN x BETWEEN 0.60 AND 0.90 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT AVG(CAST([met_target] AS FLOAT)) AS x FROM [comp].[FactShiftServiceLevel] WHERE [met_target] IS NOT NULL) q

/* ---------------- Scenarios ---------------- */
UNION ALL
SELECT 'X01', 'Scenario', 'BASE and DISRUPT demand multipliers are all 1.00; PEAK has increases only', '0 violations / PEAK rows > 1',
       CONCAT(CAST(v AS VARCHAR(10)), ' / ', CAST(p AS VARCHAR(10))), CASE WHEN v = 0 AND p > 0 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT SUM(CASE WHEN [scenario_id] IN (1, 3) AND [demand_multiplier] <> 1.00 THEN 1
                      WHEN [scenario_id] = 2 AND [demand_multiplier] < 1.00 THEN 1 ELSE 0 END) AS v,
             SUM(CASE WHEN [scenario_id] = 2 AND [demand_multiplier] > 1.00 THEN 1 ELSE 0 END) AS p
      FROM [comp].[ScenarioDemandAdjustment]) q
UNION ALL
SELECT 'X02', 'Scenario', 'PEAK availability identical to BASE; DISRUPT availability never above BASE', '0 violations', CAST(x AS VARCHAR(10)),
       CASE WHEN x = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) AS x FROM [comp].[FactShiftAvailability] b
      INNER JOIN [comp].[FactShiftAvailability] o
          ON o.[store_id] = b.[store_id] AND o.[dept_id] = b.[dept_id] AND o.[day_date] = b.[day_date] AND o.[shift_code] = b.[shift_code]
      WHERE b.[scenario_id] = 1
        AND ((o.[scenario_id] = 2 AND (o.[available_regular_employees] <> b.[available_regular_employees] OR o.[max_overtime_employees] <> b.[max_overtime_employees]))
          OR (o.[scenario_id] = 3 AND (o.[available_regular_employees] > b.[available_regular_employees] OR o.[max_overtime_employees] > b.[max_overtime_employees])))) q

/* ---------------- Core-table consistency ---------------- */
UNION ALL
SELECT 'E01', 'Core data', 'Every labor band code agrees with LaborBandRule traffic ranges (training + predictions)', '0 violations',
       CAST(x AS VARCHAR(10)), CASE WHEN x = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT (SELECT COUNT(*) FROM [API].[FactDailyTrainingLaborOutput] t INNER JOIN [API].[LaborBandRule] r ON r.[recommended_labor_band_code] = t.[recommended_labor_band_code]
              WHERE t.[traffic_index] < r.[min_traffic_index] OR t.[traffic_index] > r.[max_traffic_index] OR t.[busyness_band] <> r.[busyness_band])
           + (SELECT COUNT(*) FROM [src].[FactDailyPrediction] p INNER JOIN [API].[LaborBandRule] r ON r.[recommended_labor_band_code] = p.[predicted_recommended_labor_band_code]
              WHERE p.[predicted_traffic_index] < r.[min_traffic_index] OR p.[predicted_traffic_index] > r.[max_traffic_index]) AS x) q
UNION ALL
SELECT 'E02', 'Core data', 'Staging table agrees with DimHolidayDay and FactDailyFeatures', '0 violations', CAST(x AS VARCHAR(10)),
       CASE WHEN x = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) AS x FROM [API].[StgCostcoDailyAuditWide] w
      INNER JOIN [API].[DimHolidayDay] h ON h.[day_date] = w.[day_date]
      INNER JOIN [API].[FactDailyFeatures] f ON f.[store_id] = w.[store_id] AND f.[dept_id] = w.[dept_id] AND f.[day_date] = w.[day_date]
      WHERE w.[is_pre_holiday_stockup] <> h.[is_pre_holiday_stockup] OR w.[holiday_grocery_intensity] <> h.[holiday_grocery_intensity]
         OR w.[has_promotion] <> f.[has_promotion] OR w.[promotion_index] <> f.[promotion_index]) q
UNION ALL
SELECT 'E03', 'Core data', 'INFO (known limitation): share of open days whose daily labor band is Peak Coverage', 'informational',
       CONCAT(CAST(CAST(100.0 * x AS DECIMAL(5,1)) AS VARCHAR(10)), '%'), 'INFO'
FROM (SELECT AVG(CASE WHEN [recommended_labor_band_code] = 5 THEN 1.0 ELSE 0.0 END) AS x
      FROM [API].[FactDailyTrainingLaborOutput] WHERE [recommended_labor_band_code] > 0) q

/* ---------------- Labelling ---------------- */
UNION ALL
SELECT 'L01', 'Labels', 'Every shift-level fact/assumption row carries an allowed value_type label', '0 violations', CAST(x AS VARCHAR(10)),
       CASE WHEN x = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT (SELECT COUNT(*) FROM [comp].[FactShiftDemand] WHERE [value_type] <> 'Historical')
           + (SELECT COUNT(*) FROM [comp].[FactShiftSchedule] WHERE [value_type] NOT IN ('Historical', 'Planned (current draft)'))
           + (SELECT COUNT(*) FROM [comp].[FactShiftAvailability] WHERE [value_type] NOT IN ('Historical', 'Forecast', 'Scenario-generated'))
           + (SELECT COUNT(*) FROM [comp].[FactShiftServiceLevel] WHERE [value_type] <> 'Historical')
           + (SELECT COUNT(*) FROM [comp].[ScenarioDemandAdjustment] WHERE [value_type] NOT IN ('Forecast', 'Scenario-generated'))
           + (SELECT COUNT(*) FROM [comp].[LaborCostAssumption] WHERE [value_type] <> 'Assumed')
           + (SELECT COUNT(*) FROM [comp].[ShiftDefinition] WHERE [value_type] <> 'Assumed') AS x) q

) checks
ORDER BY check_id;
GO
