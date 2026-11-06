
/*
LaunchProject Costco-like mock seed data
Purpose: local development seed data for SQL Server / SSMS.
Date range: 2026-01-01 through 2026-02-11 (6 weeks).
Notes:
- Departments are exactly: Front End, Merchandising/Stocking, Pharmacy.
- This script clears reloadable mock data and repopulates six weeks of seeded data.
- Data was shaped to look more realistic: department-specific weekday/weekend patterns, holiday effects, and non-linear weekly demand.
- It intentionally does NOT populate [src].[Notification].
*/
SET NOCOUNT ON;
GO

USE [LaunchProject];
GO

BEGIN TRY
    BEGIN TRANSACTION;

    /* Shift-planning tables reference rows deleted below, so clear them first (no-op if absent). */
    IF OBJECT_ID(N'[comp].[ScenarioDemandAdjustment]', N'U') IS NOT NULL EXEC(N'DELETE FROM [comp].[ScenarioDemandAdjustment]');
    IF OBJECT_ID(N'[comp].[FactShiftServiceLevel]', N'U') IS NOT NULL EXEC(N'DELETE FROM [comp].[FactShiftServiceLevel]');
    IF OBJECT_ID(N'[comp].[FactShiftAvailability]', N'U') IS NOT NULL EXEC(N'DELETE FROM [comp].[FactShiftAvailability]');
    IF OBJECT_ID(N'[comp].[FactShiftSchedule]', N'U') IS NOT NULL EXEC(N'DELETE FROM [comp].[FactShiftSchedule]');
    IF OBJECT_ID(N'[comp].[FactShiftDemand]', N'U') IS NOT NULL EXEC(N'DELETE FROM [comp].[FactShiftDemand]');
    IF OBJECT_ID(N'[comp].[LaborCostAssumption]', N'U') IS NOT NULL EXEC(N'DELETE FROM [comp].[LaborCostAssumption]');
    IF OBJECT_ID(N'[comp].[ServiceMetricDefinition]', N'U') IS NOT NULL EXEC(N'DELETE FROM [comp].[ServiceMetricDefinition]');
    IF OBJECT_ID(N'[comp].[LaborStandard]', N'U') IS NOT NULL EXEC(N'DELETE FROM [comp].[LaborStandard]');
    IF OBJECT_ID(N'[comp].[ShiftDefinition]', N'U') IS NOT NULL EXEC(N'DELETE FROM [comp].[ShiftDefinition]');

    /* Clear reloadable mock data. Notification is intentionally untouched. */
    DELETE FROM [src].[FactDailyPrediction];
    DELETE FROM [API].[FactDailyTrainingLaborOutput];
    DELETE FROM [API].[FactDailyTargetAudit];
    DELETE FROM [API].[FactDailyFeatures];
    DELETE FROM [API].[FactWeeklyStoreDeptSales];
    DELETE FROM [API].[StgCostcoDailyAuditWide];
    DELETE FROM [model].[ModelFeatureRegistry];
    DELETE FROM [model].[ModelRun];
    DELETE FROM [API].[TrafficThresholdRule];
    DELETE FROM [API].[LaborBandRule];
    DELETE FROM [API].[DimHolidayDay];
    DELETE FROM [API].[DimCalendarDay];
    DELETE FROM [API].[DimDepartment];
    DELETE FROM [API].[DimStore];

    INSERT INTO [API].[DimStore] ([store_id], [store_type], [store_size], [store_size_category])
    VALUES
        (1, N'Costco Warehouse Type A', 151315, N'Medium'),
        (2, N'Costco Warehouse Type A', 202307, N'Large'),
        (4, N'Costco Warehouse Type A', 205863, N'Large');

    INSERT INTO [API].[DimDepartment] ([dept_id], [department_group], [holiday_department_profile])
    VALUES
        (38, N'Front End', N'Front End Coverage'),
        (92, N'Merchandising/Stocking', N'Merchandising / Stocking Coverage'),
        (95, N'Pharmacy', N'Pharmacy Coverage');

    IF OBJECT_ID('tempdb..#CalendarSeed') IS NOT NULL DROP TABLE #CalendarSeed;
    CREATE TABLE #CalendarSeed (
        day_index int NOT NULL,
        day_date date NOT NULL,
        week_start_date date NOT NULL,
        day_of_week int NOT NULL,
        day_name nvarchar(20) NOT NULL,
        [month] int NOT NULL,
        [quarter] int NOT NULL,
        week_of_year int NOT NULL,
        is_weekend bit NOT NULL,
        is_holiday bit NOT NULL,
        holiday_name nvarchar(100) NULL,
        holiday_type nvarchar(100) NULL,
        holiday_window_role nvarchar(100) NULL,
        is_costco_closed bit NOT NULL
    );

    ;WITH N AS (
        SELECT 0 AS n
        UNION ALL
        SELECT n + 1
        FROM N
        WHERE n < 41
    )
    INSERT INTO #CalendarSeed (
        day_index, day_date, week_start_date, day_of_week, day_name, [month], [quarter], week_of_year,
        is_weekend, is_holiday, holiday_name, holiday_type, holiday_window_role, is_costco_closed
    )
    SELECT
        n.n AS day_index,
        DATEADD(day, n.n, CAST('2026-01-01' AS date)) AS day_date,
        DATEADD(day, -(n.n % 7), DATEADD(day, n.n, CAST('2026-01-01' AS date))) AS week_start_date,
        ((n.n + 3) % 7) + 1 AS day_of_week,
        CASE (n.n % 7)
            WHEN 0 THEN N'Thursday'
            WHEN 1 THEN N'Friday'
            WHEN 2 THEN N'Saturday'
            WHEN 3 THEN N'Sunday'
            WHEN 4 THEN N'Monday'
            WHEN 5 THEN N'Tuesday'
            ELSE N'Wednesday'
        END AS day_name,
        DATEPART(month, DATEADD(day, n.n, CAST('2026-01-01' AS date))) AS [month],
        DATEPART(quarter, DATEADD(day, n.n, CAST('2026-01-01' AS date))) AS [quarter],
        1 + (n.n / 7) AS week_of_year,
        CASE WHEN (n.n % 7) IN (2, 3) THEN 1 ELSE 0 END AS is_weekend,
        CASE WHEN DATEADD(day, n.n, CAST('2026-01-01' AS date)) IN ('2026-01-01', '2026-01-19') THEN 1 ELSE 0 END AS is_holiday,
        CASE
            WHEN DATEADD(day, n.n, CAST('2026-01-01' AS date)) = '2026-01-01' THEN N'New Year''s Day'
            WHEN DATEADD(day, n.n, CAST('2026-01-01' AS date)) = '2026-01-19' THEN N'Martin Luther King Jr. Day'
            ELSE NULL
        END AS holiday_name,
        CASE
            WHEN DATEADD(day, n.n, CAST('2026-01-01' AS date)) = '2026-01-01' THEN N'Federal Holiday'
            WHEN DATEADD(day, n.n, CAST('2026-01-01' AS date)) = '2026-01-19' THEN N'Federal Holiday'
            ELSE NULL
        END AS holiday_type,
        CASE
            WHEN DATEADD(day, n.n, CAST('2026-01-01' AS date)) = '2026-01-01' THEN N'Closed_Holiday'
            WHEN DATEADD(day, n.n, CAST('2026-01-01' AS date)) BETWEEN '2026-01-02' AND '2026-01-04' THEN N'Post_New_Year_Rebound'
            WHEN DATEADD(day, n.n, CAST('2026-01-01' AS date)) BETWEEN '2026-01-16' AND '2026-01-18' THEN N'Pre_MLK_Weekend'
            WHEN DATEADD(day, n.n, CAST('2026-01-01' AS date)) = '2026-01-19' THEN N'MLK_Holiday'
            ELSE N'Normal'
        END AS holiday_window_role,
        CASE WHEN DATEADD(day, n.n, CAST('2026-01-01' AS date)) = '2026-01-01' THEN 1 ELSE 0 END AS is_costco_closed
    FROM N n
    OPTION (MAXRECURSION 100);

    INSERT INTO [API].[DimCalendarDay] ([day_date], [week_start_date], [day_of_week], [day_name], [month], [quarter], [week_of_year], [is_weekend], [is_holiday])
    SELECT [day_date], [week_start_date], [day_of_week], [day_name], [month], [quarter], [week_of_year], [is_weekend], [is_holiday]
    FROM #CalendarSeed;

    INSERT INTO [API].[DimHolidayDay] (
        [day_date], [holiday_name], [holiday_type], [related_holiday_name], [related_holiday_type], [holiday_window_role],
        [days_to_related_holiday], [days_since_related_holiday], [holiday_grocery_intensity], [holiday_gift_intensity],
        [holiday_cookout_intensity], [holiday_stockup_window_length], [holiday_day_of_week], [is_black_friday_period],
        [is_december_holiday_season], [is_costco_closed], [days_to_next_costco_closure], [days_since_last_costco_closure],
        [is_pre_holiday_stockup], [is_post_holiday_rebound]
    )
    SELECT
        c.day_date,
        c.holiday_name,
        c.holiday_type,
        CASE
            WHEN c.day_date BETWEEN '2026-01-01' AND '2026-01-04' THEN N'New Year''s Day'
            WHEN c.day_date BETWEEN '2026-01-16' AND '2026-01-20' THEN N'Martin Luther King Jr. Day'
            ELSE NULL
        END AS related_holiday_name,
        CASE
            WHEN c.day_date BETWEEN '2026-01-01' AND '2026-01-04' THEN N'Federal Holiday'
            WHEN c.day_date BETWEEN '2026-01-16' AND '2026-01-20' THEN N'Federal Holiday'
            ELSE NULL
        END AS related_holiday_type,
        c.holiday_window_role,
        CASE
            WHEN c.day_date BETWEEN '2026-01-01' AND '2026-01-04' THEN DATEDIFF(day, c.day_date, CAST('2026-01-01' AS date))
            WHEN c.day_date BETWEEN '2026-01-16' AND '2026-01-20' THEN DATEDIFF(day, c.day_date, CAST('2026-01-19' AS date))
            ELSE 999
        END AS days_to_related_holiday,
        CASE
            WHEN c.day_date BETWEEN '2026-01-01' AND '2026-01-04' THEN DATEDIFF(day, CAST('2026-01-01' AS date), c.day_date)
            WHEN c.day_date BETWEEN '2026-01-16' AND '2026-01-20' THEN DATEDIFF(day, CAST('2026-01-19' AS date), c.day_date)
            ELSE 999
        END AS days_since_related_holiday,
        CASE WHEN c.holiday_window_role <> N'Normal' THEN 0.6500 ELSE 0.0500 END AS holiday_grocery_intensity,
        CASE WHEN c.holiday_window_role <> N'Normal' THEN 0.2500 ELSE 0.0000 END AS holiday_gift_intensity,
        CASE WHEN c.holiday_window_role <> N'Normal' THEN 0.0500 ELSE 0.0000 END AS holiday_cookout_intensity,
        CASE WHEN c.holiday_window_role <> N'Normal' THEN 4 ELSE 0 END AS holiday_stockup_window_length,
        c.day_name AS holiday_day_of_week,
        0 AS is_black_friday_period,
        0 AS is_december_holiday_season,
        c.is_costco_closed,
        CASE WHEN c.is_costco_closed = 1 THEN 0 ELSE 999 END AS days_to_next_costco_closure,
        CASE WHEN c.day_date >= '2026-01-01' THEN DATEDIFF(day, CAST('2026-01-01' AS date), c.day_date) ELSE 999 END AS days_since_last_costco_closure,
        CASE WHEN c.day_date BETWEEN '2026-01-16' AND '2026-01-18' THEN 1 ELSE 0 END AS is_pre_holiday_stockup,
        CASE WHEN c.day_date BETWEEN '2026-01-02' AND '2026-01-04' OR c.day_date = '2026-01-20' THEN 1 ELSE 0 END AS is_post_holiday_rebound
    FROM #CalendarSeed c;

    INSERT INTO [API].[LaborBandRule] ([recommended_labor_band_code], [recommended_labor_band], [busyness_band], [min_traffic_index], [max_traffic_index], [description])
    VALUES
        (0, N'Closed', N'Closed', 0.00, 0.00, N'Warehouse closed; no floor labor coverage planned.'),
        (1, N'Minimal Coverage', N'Low', 0.01, 24.99, N'Very low member traffic; maintain core coverage only.'),
        (2, N'Light Coverage', N'Standard', 25.00, 49.99, N'Low member traffic; schedule lean coverage with targeted cross-trained support.'),
        (3, N'Standard Coverage', N'High', 50.00, 84.99, N'Normal operating day; staff standard lanes, stocking, and pharmacy areas.'),
        (4, N'Add Flex Coverage', N'Peak', 85.00, 99.99, N'High member traffic; add flex support to front end, merchandising, and pharmacy.'),
        (5, N'Peak Coverage', N'Peak', 100.00, 999.00, N'Peak traffic; maximize checkout, stocking, and department support.');

    INSERT INTO [API].[TrafficThresholdRule] (
        [store_size_category], [poc_department_group], [very_low_max_transactions], [low_max_transactions],
        [standard_max_transactions], [high_max_transactions], [peak_min_transactions], [effective_start_date],
        [effective_end_date], [notes]
    )
    VALUES
        (N'Large', N'Front End', 35.00, 45.00, 65.00, 85.00, 85.01, '2026-01-01', NULL, N'Mock thresholds for Large Front End.'),
        (N'Large', N'Merchandising/Stocking', 80.00, 95.00, 120.00, 150.00, 150.01, '2026-01-01', NULL, N'Mock thresholds for Large Merchandising/Stocking.'),
        (N'Large', N'Pharmacy', 45.00, 60.00, 80.00, 100.00, 100.01, '2026-01-01', NULL, N'Mock thresholds for Large Pharmacy.'),
        (N'Medium', N'Front End', 30.00, 40.00, 58.00, 78.00, 78.01, '2026-01-01', NULL, N'Mock thresholds for Medium Front End.'),
        (N'Medium', N'Merchandising/Stocking', 72.00, 88.00, 112.00, 142.00, 142.01, '2026-01-01', NULL, N'Mock thresholds for Medium Merchandising/Stocking.'),
        (N'Medium', N'Pharmacy', 40.00, 52.00, 70.00, 90.00, 90.01, '2026-01-01', NULL, N'Mock thresholds for Medium Pharmacy.');

    IF OBJECT_ID('tempdb..#BaseCombo') IS NOT NULL DROP TABLE #BaseCombo;
    CREATE TABLE #BaseCombo (
        store_id int NOT NULL,
        dept_id int NOT NULL,
        department_group nvarchar(100) NOT NULL,
        store_size int NOT NULL,
        store_size_category nvarchar(20) NOT NULL,
        weekly_sales_base decimal(18,2) NOT NULL,
        traffic_multiplier decimal(9,4) NOT NULL,
        dept_impact_factor decimal(9,4) NOT NULL,
        base_ticket decimal(9,2) NOT NULL,
        temp_base decimal(9,2) NOT NULL,
        fuel_base decimal(9,4) NOT NULL,
        promo_base decimal(9,4) NOT NULL
    );

    INSERT INTO #BaseCombo (
        store_id, dept_id, department_group, store_size, store_size_category, weekly_sales_base,
        traffic_multiplier, dept_impact_factor, base_ticket, temp_base, fuel_base, promo_base
    )
    VALUES
        (1, 38, N'Front End', 151315, N'Medium', 98000.00, 1.1800, 1.0500, 145.00, 54.00, 3.1600, 0.6500),
        (1, 92, N'Merchandising/Stocking', 151315, N'Medium', 185000.00, 0.7800, 1.1000, 205.00, 52.00, 3.1600, 1.1000),
        (1, 95, N'Pharmacy', 151315, N'Medium', 76000.00, 0.7200, 0.6500, 82.00, 53.00, 3.1600, 0.3500),
        (2, 38, N'Front End', 202307, N'Large', 118000.00, 1.2200, 1.0500, 148.00, 53.00, 3.1550, 0.6500),
        (2, 92, N'Merchandising/Stocking', 202307, N'Large', 225000.00, 0.8000, 1.1000, 210.00, 51.00, 3.1550, 1.1000),
        (2, 95, N'Pharmacy', 202307, N'Large', 90000.00, 0.7400, 0.6500, 84.00, 52.00, 3.1550, 0.3500),
        (4, 38, N'Front End', 205863, N'Large', 122000.00, 1.2300, 1.0500, 146.00, 49.00, 3.1400, 0.6500),
        (4, 92, N'Merchandising/Stocking', 205863, N'Large', 215000.00, 0.7900, 1.1000, 208.00, 48.00, 3.1400, 1.1000),
        (4, 95, N'Pharmacy', 205863, N'Large', 94000.00, 0.7500, 0.6500, 83.00, 49.00, 3.1400, 0.3500);

    IF OBJECT_ID('tempdb..#WeeklySeed') IS NOT NULL DROP TABLE #WeeklySeed;
    CREATE TABLE #WeeklySeed (
        store_id int NOT NULL,
        dept_id int NOT NULL,
        week_start_date date NOT NULL,
        weekly_sales decimal(18,2) NOT NULL,
        source_file_name nvarchar(200) NOT NULL
    );

    ;WITH W AS (
        SELECT 0 AS week_index
        UNION ALL
        SELECT week_index + 1
        FROM W
        WHERE week_index < 5
    )
    INSERT INTO #WeeklySeed (store_id, dept_id, week_start_date, weekly_sales, source_file_name)
    SELECT
        b.store_id,
        b.dept_id,
        DATEADD(day, w.week_index * 7, CAST('2026-01-01' AS date)) AS week_start_date,
        ROUND(
            b.weekly_sales_base
            * (1.0
               + CASE w.week_index
                    WHEN 0 THEN -0.0200
                    WHEN 1 THEN  0.0150
                    WHEN 2 THEN  0.0550
                    WHEN 3 THEN  0.0250
                    WHEN 4 THEN -0.0100
                    ELSE 0.0350
                 END
               + CASE WHEN b.store_size_category = N'Large' THEN 0.0400 ELSE 0.0000 END
               + CASE
                    WHEN b.dept_id = 38 AND w.week_index IN (0, 2, 5) THEN 0.0300
                    WHEN b.dept_id = 92 AND w.week_index IN (1, 2) THEN 0.0400
                    WHEN b.dept_id = 95 AND w.week_index IN (2, 3) THEN 0.0200
                    ELSE 0.0000
                 END),
            2
        ) AS weekly_sales,
        N'Mock_2026_Q1.csv' AS source_file_name
    FROM #BaseCombo b
    CROSS JOIN W w
    OPTION (MAXRECURSION 100);

    INSERT INTO [API].[FactWeeklyStoreDeptSales] ([store_id], [dept_id], [week_start_date], [weekly_sales], [source_file_name])
    SELECT store_id, dept_id, week_start_date, weekly_sales, source_file_name
    FROM #WeeklySeed;

    IF OBJECT_ID('tempdb..#DailySeed') IS NOT NULL DROP TABLE #DailySeed;
    CREATE TABLE #DailySeed (
        store_id int NOT NULL,
        dept_id int NOT NULL,
        day_date date NOT NULL,
        week_start_date date NOT NULL,
        day_index int NOT NULL,
        week_of_year int NOT NULL,
        day_of_week int NOT NULL,
        day_name nvarchar(20) NOT NULL,
        [month] int NOT NULL,
        [quarter] int NOT NULL,
        is_weekend bit NOT NULL,
        is_holiday bit NOT NULL,
        holiday_name nvarchar(100) NULL,
        holiday_type nvarchar(100) NULL,
        holiday_window_role nvarchar(100) NULL,
        is_costco_closed bit NOT NULL,
        store_size int NOT NULL,
        store_size_category nvarchar(20) NOT NULL,
        department_group nvarchar(100) NOT NULL,
        weekly_sales decimal(18,2) NOT NULL,
        weekly_sales_base decimal(18,2) NOT NULL,
        traffic_multiplier decimal(9,4) NOT NULL,
        dept_impact_factor decimal(9,4) NOT NULL,
        base_ticket decimal(9,2) NOT NULL,
        temp_base decimal(9,2) NOT NULL,
        fuel_base decimal(9,4) NOT NULL,
        promo_base decimal(9,4) NOT NULL
    );

    INSERT INTO #DailySeed (
        store_id, dept_id, day_date, week_start_date, day_index, week_of_year, day_of_week, day_name, [month], [quarter],
        is_weekend, is_holiday, holiday_name, holiday_type, holiday_window_role, is_costco_closed, store_size,
        store_size_category, department_group, weekly_sales, weekly_sales_base, traffic_multiplier, dept_impact_factor,
        base_ticket, temp_base, fuel_base, promo_base
    )
    SELECT
        b.store_id,
        b.dept_id,
        c.day_date,
        c.week_start_date,
        c.day_index,
        c.week_of_year,
        c.day_of_week,
        c.day_name,
        c.[month],
        c.[quarter],
        c.is_weekend,
        c.is_holiday,
        c.holiday_name,
        c.holiday_type,
        c.holiday_window_role,
        c.is_costco_closed,
        b.store_size,
        b.store_size_category,
        b.department_group,
        w.weekly_sales,
        b.weekly_sales_base,
        b.traffic_multiplier,
        b.dept_impact_factor,
        b.base_ticket,
        b.temp_base,
        b.fuel_base,
        b.promo_base
    FROM #BaseCombo b
    INNER JOIN #CalendarSeed c
        ON 1 = 1
    INNER JOIN #WeeklySeed w
        ON w.store_id = b.store_id
       AND w.dept_id = b.dept_id
       AND w.week_start_date = c.week_start_date;

    /* Update/insert employee mock data without deleting existing linked employees. */
    MERGE [API].[Employee] AS target
    USING (VALUES
        (1001, N'Alex Rivera', N'[38]', N'[1, 2, 4]', N'Front End Supervisor', 40.0),
        (1002, N'Jamie Patel', N'[92]', N'[1, 2, 4]', N'Merchandising Supervisor', 40.0),
        (1003, N'Taylor Brooks', N'[95]', N'[1, 2, 4]', N'Pharmacy Manager', 40.0),
        (1004, N'Morgan Lee', N'[38, 92]', N'[1, 2]', N'Front End Lead', 36.0),
        (1005, N'Casey Nguyen', N'[92]', N'[2, 4]', N'Stocking Specialist', 34.0),
        (1006, N'Riley Chen', N'[38, 95]', N'[1, 4]', N'Pharmacy Technician', 32.0),
        (1007, N'Harper Johnson', N'[38]', N'[1]', N'Cashier', 28.0),
        (1008, N'Noah Kim', N'[92]', N'[2]', N'Stocker', 30.0),
        (1009, N'Sofia Martinez', N'[95]', N'[4]', N'Pharmacy Clerk', 28.0)
    ) AS source ([ID], [name], [DepartmentIds], [storeIds], [role], [availableHours])
        ON target.[ID] = source.[ID]
    WHEN MATCHED THEN
        UPDATE SET
            [name] = source.[name],
            [DepartmentIds] = source.[DepartmentIds],
            [storeIds] = source.[storeIds],
            [role] = source.[role],
            [availableHours] = source.[availableHours]
    WHEN NOT MATCHED THEN
        INSERT ([ID], [name], [DepartmentIds], [storeIds], [role], [availableHours])
        VALUES (source.[ID], source.[name], source.[DepartmentIds], source.[storeIds], source.[role], source.[availableHours]);

    INSERT INTO [model].[ModelRun] (
        [model_run_id], [model_name], [model_version], [model_algorithm], [trained_at], [scored_at],
        [training_data_start], [training_data_end], [scoring_data_start], [scoring_data_end], [feature_set_name], [notes]
    )
    VALUES
        (2026010101, N'Costco Labor Busyness Forecast', N'mock-1.0', N'Explainable Boosting Machine',
         '2026-01-01T09:00:00', '2026-01-01T09:15:00',
         '2025-01-01', '2025-12-31', '2026-01-01', '2026-02-11',
         N'costco_6_week_january_features',
         N'Mock model run seeded for six weeks starting 2026-01-01.');

    INSERT INTO [model].[ModelFeatureRegistry] (
        [column_name], [variable_group], [poc_role], [data_type], [business_meaning], [source_or_derivation],
        [use_in_ebm_busyness_model], [ebm_model_treatment], [use_in_post_model_labor_rules], [business_rule_use],
        [leakage_risk], [in_full_train_audit_file], [in_full_test_scoring_features_file], [in_ebm_train_model_only_file],
        [in_ebm_test_model_only_file], [expected_final_output_field], [train_profile], [test_profile],
        [missing_or_none_handling], [recommended_preprocessing], [notes], [loaded_at]
    )
    VALUES
        (N'store_id', N'Store / Warehouse', N'join_key', N'SMALLINT', N'Warehouse identifier used to segment traffic and labor planning.', N'DimStore', 1, N'categorical_id', 0, N'Join key for warehouse-level features', N'Low', 1, 1, 1, 1, 0, N'Complete for all rows', N'Required for scoring rows', N'Do not impute', N'Validate against API.DimStore', N'Seeded for three Costco warehouses.', SYSUTCDATETIME()),
        (N'dept_id', N'Department', N'join_key', N'SMALLINT', N'Department identifier used to segment sales and traffic behavior.', N'DimDepartment', 1, N'categorical_id', 0, N'Join key for department-level logic', N'Low', 1, 1, 1, 1, 0, N'Complete for all rows', N'Required for scoring rows', N'Do not impute', N'Validate against API.DimDepartment', N'Exact departments are Front End, Merchandising/Stocking, Pharmacy.', SYSUTCDATETIME()),
        (N'day_date', N'Calendar', N'join_key', N'DATE', N'Business date for daily scoring and training.', N'DimCalendarDay', 1, N'date_key', 0, N'Join key for day-level calendar logic', N'Low', 1, 1, 1, 1, 0, N'Complete six-week range', N'Required for scoring rows', N'Do not impute', N'Validate against API.DimCalendarDay', N'Seed covers 2026-01-01 through 2026-02-11.', SYSUTCDATETIME()),
        (N'is_costco_closed', N'Holiday', N'feature', N'BIT', N'Indicates a warehouse closure day.', N'DimHolidayDay', 1, N'binary_feature', 1, N'If closed, force labor band to Closed.', N'Low', 1, 1, 1, 1, 0, N'New Year''s Day marked closed', N'Required for scoring rows', N'Default to 0 only for non-holiday days', N'Use as rule override after model score', N'Critical post-model labor rule.', SYSUTCDATETIME()),
        (N'holiday_window_role', N'Holiday', N'feature', N'NVARCHAR', N'Holiday timing label for each date.', N'DimHolidayDay', 1, N'categorical_feature', 1, N'Shapes member traffic and recommended coverage.', N'Low', 1, 1, 1, 1, 0, N'Holiday and normal rows present', N'Expected in scoring set', N'Use Normal when no holiday applies', N'One-hot encode or target encode', N'Derived from calendar logic.', SYSUTCDATETIME()),
        (N'holiday_grocery_intensity', N'Holiday', N'feature', N'DECIMAL', N'Generic holiday demand intensity.', N'DimHolidayDay', 1, N'continuous_feature', 0, N'Raises labor planning sensitivity for holiday-affected departments.', N'Low', 1, 1, 1, 1, 0, N'New Year and MLK dates have elevated intensity', N'Expected in scoring set', N'Default 0.05 for normal days', N'Scale numeric value', N'Useful for forecasting holiday and weekend spikes.', SYSUTCDATETIME()),
        (N'department_holiday_impact_factor', N'Department Holiday', N'feature', N'DECIMAL', N'Department-level multiplier for holiday impact.', N'Base department mapping', 1, N'continuous_feature', 1, N'Adjusts labor rules by department profile.', N'Low', 1, 1, 1, 1, 0, N'Present for each selected row', N'Expected in scoring set', N'Default 1.0', N'Scale numeric value', N'Front End / Merchandising / Pharmacy are the only departments.', SYSUTCDATETIME()),
        (N'traffic_index', N'Labor Output', N'target_or_output', N'DECIMAL', N'Indexed traffic proxy used to assign labor band.', N'FactDailyTrainingLaborOutput', 0, N'target_output', 1, N'Used to map traffic to labor coverage.', N'Medium', 1, 0, 0, 0, 1, N'Generated from daily seed data', N'Not available before scoring', N'Never use as model input for scored rows', N'Output/audit only', N'Potential leakage if used as an input feature.', SYSUTCDATETIME()),
        (N'recommended_labor_band_code', N'Labor Output', N'target_or_output', N'SMALLINT', N'Numeric labor recommendation code.', N'FactDailyTrainingLaborOutput and FactDailyPrediction', 0, N'target_output', 1, N'Primary downstream labor recommendation code.', N'Medium', 1, 0, 0, 0, 1, N'Present in training output', N'Predicted by scoring step', N'Never impute as input', N'Output/audit only', N'Use as final recommendation output.', SYSUTCDATETIME()),
        (N'predicted_traffic_index', N'Prediction', N'model_output', N'DECIMAL', N'Predicted traffic index for scored warehouse/day/department.', N'src.FactDailyPrediction', 0, N'model_output', 1, N'Used to assign predicted labor band.', N'Low', 0, 1, 0, 1, 1, N'Not in raw training file', N'Generated by model run', N'Produced by model', N'Do not preprocess as input', N'Included in final prediction view.', SYSUTCDATETIME()),
        (N'average_ticket_proxy', N'Transaction Proxy', N'feature', N'DECIMAL', N'Average ticket proxy used to convert sales proxy into transaction count proxy.', N'Base department mapping', 1, N'continuous_feature', 0, N'Supports busyness and traffic derivations.', N'Low', 1, 1, 1, 1, 0, N'Complete for selected rows', N'Expected in scoring set', N'Impute by store and department average', N'Scale numeric value', N'Ticket values were adjusted for the January 2026 seed.', SYSUTCDATETIME());

    INSERT INTO [API].[FactDailyFeatures] (
        [store_id], [dept_id], [day_date], [dataset_partition], [temperature], [fuel_price], [markdown1], [markdown2], [markdown3],
        [markdown4], [markdown5], [cpi], [unemployment], [temperature_category], [promotion_index], [has_promotion],
        [department_holiday_impact_factor], [average_ticket_proxy], [source_file_name]
    )
    SELECT
        d.store_id,
        d.dept_id,
        d.day_date,
        N'train' AS dataset_partition,
        t.temperature,
        ROUND(d.fuel_base + (d.week_of_year * 0.0150), 4) AS fuel_price,
        ROUND(d.weekly_sales * 0.0040 + (d.day_index % 7) * 9.0, 2) AS markdown1,
        ROUND(d.weekly_sales * 0.0010 + 15.0, 2) AS markdown2,
        ROUND(d.weekly_sales * CASE WHEN d.dept_id = 92 THEN 0.0550 WHEN d.dept_id = 38 THEN 0.0200 ELSE 0.0120 END, 2) AS markdown3,
        ROUND(5.0 + (d.day_index % 7) * 1.7, 2) AS markdown4,
        ROUND(d.weekly_sales * CASE WHEN d.dept_id = 92 THEN 0.0250 WHEN d.dept_id = 38 THEN 0.0120 ELSE 0.0080 END, 2) AS markdown5,
        ROUND(210.0 + d.store_id * 2.25 + d.week_of_year * 0.80, 4) AS cpi,
        ROUND(4.25 + (d.store_id * 0.08) + CASE d.dept_id WHEN 92 THEN 0.20 WHEN 95 THEN 0.12 ELSE 0.05 END, 3) AS unemployment,
        CASE
            WHEN t.temperature < 45 THEN N'Cold'
            WHEN t.temperature < 60 THEN N'Mild'
            ELSE N'Warm'
        END AS temperature_category,
        ROUND(d.promo_base + CASE WHEN d.day_of_week IN (5, 6, 7) THEN 0.1500 WHEN d.holiday_window_role <> N'Normal' THEN 0.1000 ELSE 0.0000 END, 4) AS promotion_index,
        CASE WHEN d.day_of_week IN (5, 6, 7) OR d.holiday_window_role <> N'Normal' THEN 1 ELSE 0 END AS has_promotion,
        d.dept_impact_factor AS department_holiday_impact_factor,
        ROUND(d.base_ticket + (d.week_of_year * 0.55) + (d.day_index % 7) * 0.85, 2) AS average_ticket_proxy,
        N'Mock_2026_Q1.csv' AS source_file_name
    FROM #DailySeed d
    CROSS APPLY (
        VALUES (ROUND(d.temp_base + ((d.day_index % 7) * 1.10) - (d.week_of_year * 0.35), 3))
    ) AS t(temperature);

    INSERT INTO [API].[FactDailyTargetAudit] (
        [store_id], [dept_id], [day_date], [weekly_sales], [base_daily_weight], [holiday_adjustment_factor],
        [adjusted_daily_weight], [daily_weight], [daily_promotion_index], [daily_sales_proxy], [busyness_proxy]
    )
    SELECT
        d.store_id,
        d.dept_id,
        d.day_date,
        d.weekly_sales,
        bw.base_daily_weight,
        hf.holiday_adjustment_factor,
        ROUND(bw.base_daily_weight * hf.holiday_adjustment_factor, 4) AS adjusted_daily_weight,
        ROUND(bw.base_daily_weight * hf.holiday_adjustment_factor, 4) AS daily_weight,
        ROUND((d.promo_base + CASE WHEN d.day_of_week IN (5, 6, 7) THEN 0.1500 ELSE 0.0000 END) * 0.10, 4) AS daily_promotion_index,
        ROUND(d.weekly_sales * bw.base_daily_weight * hf.holiday_adjustment_factor, 2) AS daily_sales_proxy,
        ROUND(
            d.weekly_sales * bw.base_daily_weight * hf.holiday_adjustment_factor
            * (1.0 + CASE d.dept_id WHEN 38 THEN 0.22 WHEN 92 THEN 0.30 WHEN 95 THEN 0.10 ELSE 0.00 END),
            2
        ) AS busyness_proxy
    FROM #DailySeed d
    CROSS APPLY (
        VALUES (
            CASE
                WHEN d.dept_id = 38 THEN
                    CASE d.day_of_week
                        WHEN 1 THEN 0.1100
                        WHEN 2 THEN 0.1150
                        WHEN 3 THEN 0.1250
                        WHEN 4 THEN 0.1350
                        WHEN 5 THEN 0.1650
                        WHEN 6 THEN 0.1850
                        ELSE 0.1650
                    END
                WHEN d.dept_id = 92 THEN
                    CASE d.day_of_week
                        WHEN 1 THEN 0.1650
                        WHEN 2 THEN 0.1500
                        WHEN 3 THEN 0.1350
                        WHEN 4 THEN 0.1300
                        WHEN 5 THEN 0.1450
                        WHEN 6 THEN 0.1450
                        ELSE 0.1300
                    END
                ELSE
                    CASE d.day_of_week
                        WHEN 1 THEN 0.1750
                        WHEN 2 THEN 0.1800
                        WHEN 3 THEN 0.1750
                        WHEN 4 THEN 0.1700
                        WHEN 5 THEN 0.1650
                        WHEN 6 THEN 0.0900
                        ELSE 0.0450
                    END
            END
        )
    ) AS bw(base_daily_weight)
    CROSS APPLY (
        VALUES (
            CASE
                WHEN d.is_costco_closed = 1 THEN 0.00
                WHEN d.holiday_window_role = N'Post_New_Year_Rebound' THEN CASE WHEN d.dept_id = 38 THEN 1.1000 WHEN d.dept_id = 92 THEN 1.0600 ELSE 0.9000 END
                WHEN d.holiday_window_role = N'Pre_MLK_Weekend' THEN CASE WHEN d.dept_id = 38 THEN 1.1200 WHEN d.dept_id = 92 THEN 1.0800 ELSE 0.9500 END
                WHEN d.holiday_window_role = N'MLK_Holiday' THEN CASE WHEN d.dept_id = 95 THEN 0.7000 ELSE 1.0500 END
                ELSE 1.00
            END
        )
    ) AS hf(holiday_adjustment_factor);

    INSERT INTO [API].[FactDailyTrainingLaborOutput] (
        [store_id], [dept_id], [day_date], [transaction_count_proxy], [traffic_index], [busyness_band],
        [labor_planning_context], [recommended_labor_band], [recommended_labor_band_code], [labor_rule_reason]
    )
    SELECT
        d.store_id,
        d.dept_id,
        d.day_date,
        CASE
            WHEN d.is_costco_closed = 1 THEN 0.0000
            ELSE ROUND(ta.daily_sales_proxy / d.base_ticket, 4)
        END AS transaction_count_proxy,
        CASE
            WHEN d.is_costco_closed = 1 THEN 0.00
            ELSE ROUND((ta.daily_sales_proxy / d.base_ticket) * d.traffic_multiplier, 2)
        END AS traffic_index,
        CASE
            WHEN d.is_costco_closed = 1 THEN N'Closed'
            WHEN ROUND((ta.daily_sales_proxy / d.base_ticket) * d.traffic_multiplier, 2) < 25 THEN N'Low'
            WHEN ROUND((ta.daily_sales_proxy / d.base_ticket) * d.traffic_multiplier, 2) < 50 THEN N'Standard'
            WHEN ROUND((ta.daily_sales_proxy / d.base_ticket) * d.traffic_multiplier, 2) < 85 THEN N'High'
            ELSE N'Peak'
        END AS busyness_band,
        CASE
            WHEN d.is_costco_closed = 1 THEN N'Closed_Holiday'
            WHEN ROUND((ta.daily_sales_proxy / d.base_ticket) * d.traffic_multiplier, 2) >= 85 THEN N'Peak_Demand'
            WHEN ROUND((ta.daily_sales_proxy / d.base_ticket) * d.traffic_multiplier, 2) >= 50 THEN N'Standard_Day'
            ELSE N'Light_Day'
        END AS labor_planning_context,
        CASE
            WHEN d.is_costco_closed = 1 THEN N'Closed'
            WHEN ROUND((ta.daily_sales_proxy / d.base_ticket) * d.traffic_multiplier, 2) < 25 THEN N'Minimal Coverage'
            WHEN ROUND((ta.daily_sales_proxy / d.base_ticket) * d.traffic_multiplier, 2) < 50 THEN N'Light Coverage'
            WHEN ROUND((ta.daily_sales_proxy / d.base_ticket) * d.traffic_multiplier, 2) < 85 THEN N'Standard Coverage'
            WHEN ROUND((ta.daily_sales_proxy / d.base_ticket) * d.traffic_multiplier, 2) < 100 THEN N'Add Flex Coverage'
            ELSE N'Peak Coverage'
        END AS recommended_labor_band,
        CASE
            WHEN d.is_costco_closed = 1 THEN 0
            WHEN ROUND((ta.daily_sales_proxy / d.base_ticket) * d.traffic_multiplier, 2) < 25 THEN 1
            WHEN ROUND((ta.daily_sales_proxy / d.base_ticket) * d.traffic_multiplier, 2) < 50 THEN 2
            WHEN ROUND((ta.daily_sales_proxy / d.base_ticket) * d.traffic_multiplier, 2) < 85 THEN 3
            WHEN ROUND((ta.daily_sales_proxy / d.base_ticket) * d.traffic_multiplier, 2) < 100 THEN 4
            ELSE 5
        END AS recommended_labor_band_code,
        CASE
            WHEN d.is_costco_closed = 1 THEN N'New Year''s Day closure; traffic forced to zero.'
            WHEN ROUND((ta.daily_sales_proxy / d.base_ticket) * d.traffic_multiplier, 2) >= 85 THEN N'Peak demand day driven by daily sales and traffic multiplier.'
            WHEN ROUND((ta.daily_sales_proxy / d.base_ticket) * d.traffic_multiplier, 2) >= 50 THEN N'Standard demand day driven by daily sales and traffic multiplier.'
            ELSE N'Light demand day driven by daily sales and traffic multiplier.'
        END AS labor_rule_reason
    FROM #DailySeed d
    INNER JOIN [API].[FactDailyTargetAudit] ta
        ON ta.store_id = d.store_id
       AND ta.dept_id = d.dept_id
       AND ta.day_date = d.day_date;

    INSERT INTO [src].[FactDailyPrediction] (
        [model_run_id], [store_id], [dept_id], [day_date], [predicted_busyness_proxy], [predicted_transaction_count_proxy],
        [predicted_traffic_index], [predicted_busyness_band], [predicted_labor_planning_context],
        [predicted_recommended_labor_band], [predicted_recommended_labor_band_code], [predicted_labor_rule_reason]
    )
    SELECT
        2026010101 AS model_run_id,
        d.store_id,
        d.dept_id,
        d.day_date,
        CASE WHEN d.is_costco_closed = 1 THEN 0.00 ELSE ROUND(ta.busyness_proxy * 1.02, 2) END AS predicted_busyness_proxy,
        CASE WHEN d.is_costco_closed = 1 THEN 0.0000 ELSE ROUND(tl.transaction_count_proxy * 1.01, 4) END AS predicted_transaction_count_proxy,
        CASE WHEN d.is_costco_closed = 1 THEN 0.00 ELSE ROUND(tl.traffic_index * 1.03, 2) END AS predicted_traffic_index,
        CASE
            WHEN d.is_costco_closed = 1 THEN N'Closed'
            WHEN ROUND(tl.traffic_index * 1.03, 2) < 25 THEN N'Low'
            WHEN ROUND(tl.traffic_index * 1.03, 2) < 50 THEN N'Standard'
            WHEN ROUND(tl.traffic_index * 1.03, 2) < 85 THEN N'High'
            ELSE N'Peak'
        END AS predicted_busyness_band,
        CASE
            WHEN d.is_costco_closed = 1 THEN N'Costco_Closed_Day'
            WHEN ROUND(tl.traffic_index * 1.03, 2) >= 85 THEN N'Peak_Demand'
            WHEN ROUND(tl.traffic_index * 1.03, 2) >= 50 THEN N'Standard_Day'
            ELSE N'Light_Day'
        END AS predicted_labor_planning_context,
        CASE
            WHEN d.is_costco_closed = 1 THEN N'Closed'
            WHEN ROUND(tl.traffic_index * 1.03, 2) < 25 THEN N'Minimal Coverage'
            WHEN ROUND(tl.traffic_index * 1.03, 2) < 50 THEN N'Light Coverage'
            WHEN ROUND(tl.traffic_index * 1.03, 2) < 85 THEN N'Standard Coverage'
            WHEN ROUND(tl.traffic_index * 1.03, 2) < 100 THEN N'Add Flex Coverage'
            ELSE N'Peak Coverage'
        END AS predicted_recommended_labor_band,
        CASE
            WHEN d.is_costco_closed = 1 THEN 0
            WHEN ROUND(tl.traffic_index * 1.03, 2) < 25 THEN 1
            WHEN ROUND(tl.traffic_index * 1.03, 2) < 50 THEN 2
            WHEN ROUND(tl.traffic_index * 1.03, 2) < 85 THEN 3
            WHEN ROUND(tl.traffic_index * 1.03, 2) < 100 THEN 4
            ELSE 5
        END AS predicted_recommended_labor_band_code,
        CASE
            WHEN d.is_costco_closed = 1 THEN N'New Year''s Day closure prediction.'
            WHEN ROUND(tl.traffic_index * 1.03, 2) >= 85 THEN N'Predicted peak demand based on the January 2026 seed pattern.'
            WHEN ROUND(tl.traffic_index * 1.03, 2) >= 50 THEN N'Predicted standard demand based on the January 2026 seed pattern.'
            ELSE N'Predicted light demand based on the January 2026 seed pattern.'
        END AS predicted_labor_rule_reason
    FROM #DailySeed d
    INNER JOIN [API].[FactDailyTrainingLaborOutput] tl
        ON tl.store_id = d.store_id
       AND tl.dept_id = d.dept_id
       AND tl.day_date = d.day_date
    INNER JOIN [API].[FactDailyTargetAudit] ta
        ON ta.store_id = d.store_id
       AND ta.dept_id = d.dept_id
       AND ta.day_date = d.day_date;

    INSERT INTO [API].[StgCostcoDailyAuditWide] (
        [store_id], [dept_id], [poc_department_group], [store_type], [store_size], [store_size_category], [weekly_sales],
        [temperature], [fuel_price], [markdown1], [markdown2], [markdown3], [markdown4], [markdown5], [cpi], [unemployment],
        [is_holiday], [week_start_date], [day_date], [day_of_week], [day_name], [holiday_name], [holiday_type],
        [related_holiday_name], [related_holiday_type], [holiday_window_role], [days_to_related_holiday],
        [days_since_related_holiday], [holiday_grocery_intensity], [holiday_gift_intensity], [holiday_cookout_intensity],
        [holiday_stockup_window_length], [holiday_day_of_week], [is_black_friday_period], [is_december_holiday_season],
        [holiday_department_profile], [department_holiday_impact_factor], [is_costco_closed], [days_to_next_costco_closure],
        [days_since_last_costco_closure], [is_pre_holiday_stockup], [is_post_holiday_rebound], [is_weekend], [month], [quarter],
        [week_of_year], [base_daily_weight], [holiday_adjustment_factor], [adjusted_daily_weight], [daily_weight],
        [promotion_index], [has_promotion], [daily_promotion_index], [temperature_category], [daily_sales_proxy],
        [busyness_proxy], [average_ticket_proxy], [transaction_count_proxy], [traffic_index], [busyness_band],
        [labor_planning_context], [recommended_labor_band], [recommended_labor_band_code], [labor_rule_reason],
        [predicted_busyness_proxy], [predicted_transaction_count_proxy], [predicted_traffic_index], [predicted_busyness_band],
        [predicted_labor_planning_context], [predicted_recommended_labor_band], [predicted_recommended_labor_band_code],
        [predicted_labor_rule_reason], [loaded_at], [source_file_name]
    )
    /* Staging table is populated from the normalized tables so the two always agree. */
    SELECT
        d.store_id,
        d.dept_id,
        d.department_group AS poc_department_group,
        s.store_type,
        d.store_size,
        d.store_size_category,
        d.weekly_sales,
        f.temperature,
        f.fuel_price,
        f.markdown1,
        f.markdown2,
        f.markdown3,
        f.markdown4,
        f.markdown5,
        f.cpi,
        f.unemployment,
        d.is_holiday,
        d.week_start_date,
        d.day_date,
        d.day_of_week,
        d.day_name,
        h.holiday_name,
        h.holiday_type,
        h.related_holiday_name,
        h.related_holiday_type,
        h.holiday_window_role,
        h.days_to_related_holiday,
        h.days_since_related_holiday,
        h.holiday_grocery_intensity,
        h.holiday_gift_intensity,
        h.holiday_cookout_intensity,
        h.holiday_stockup_window_length,
        h.holiday_day_of_week,
        h.is_black_friday_period,
        h.is_december_holiday_season,
        dd.holiday_department_profile,
        f.department_holiday_impact_factor,
        h.is_costco_closed,
        h.days_to_next_costco_closure,
        h.days_since_last_costco_closure,
        h.is_pre_holiday_stockup,
        h.is_post_holiday_rebound,
        d.is_weekend,
        d.[month],
        d.[quarter],
        d.week_of_year,
        ta.base_daily_weight,
        ta.holiday_adjustment_factor,
        ta.adjusted_daily_weight,
        ta.daily_weight,
        f.promotion_index,
        f.has_promotion,
        ta.daily_promotion_index,
        f.temperature_category,
        ta.daily_sales_proxy,
        ta.busyness_proxy,
        f.average_ticket_proxy,
        tl.transaction_count_proxy,
        tl.traffic_index,
        tl.busyness_band,
        tl.labor_planning_context,
        tl.recommended_labor_band,
        tl.recommended_labor_band_code,
        tl.labor_rule_reason,
        pr.predicted_busyness_proxy,
        pr.predicted_transaction_count_proxy,
        pr.predicted_traffic_index,
        pr.predicted_busyness_band,
        pr.predicted_labor_planning_context,
        pr.predicted_recommended_labor_band,
        pr.predicted_recommended_labor_band_code,
        pr.predicted_labor_rule_reason,
        SYSUTCDATETIME(),
        N'Mock_2026_Q1.csv'
    FROM #DailySeed d
    INNER JOIN [API].[DimStore] s
        ON s.store_id = d.store_id
    INNER JOIN [API].[DimDepartment] dd
        ON dd.dept_id = d.dept_id
    INNER JOIN [API].[DimHolidayDay] h
        ON h.day_date = d.day_date
    INNER JOIN [API].[FactDailyFeatures] f
        ON f.store_id = d.store_id
       AND f.dept_id = d.dept_id
       AND f.day_date = d.day_date
    INNER JOIN [API].[FactDailyTargetAudit] ta
        ON ta.store_id = d.store_id
       AND ta.dept_id = d.dept_id
       AND ta.day_date = d.day_date
    INNER JOIN [API].[FactDailyTrainingLaborOutput] tl
        ON tl.store_id = d.store_id
       AND tl.dept_id = d.dept_id
       AND tl.day_date = d.day_date
    INNER JOIN [src].[FactDailyPrediction] pr
        ON pr.store_id = d.store_id
       AND pr.dept_id = d.dept_id
       AND pr.day_date = d.day_date;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

/* Validation output */
SELECT 'DimStore' AS table_name, COUNT(*) AS row_count FROM [API].[DimStore]
UNION ALL SELECT 'DimDepartment', COUNT(*) FROM [API].[DimDepartment]
UNION ALL SELECT 'DimCalendarDay', COUNT(*) FROM [API].[DimCalendarDay]
UNION ALL SELECT 'DimHolidayDay', COUNT(*) FROM [API].[DimHolidayDay]
UNION ALL SELECT 'Employee', COUNT(*) FROM [API].[Employee] WHERE [ID] BETWEEN 1001 AND 1009
UNION ALL SELECT 'FactWeeklyStoreDeptSales', COUNT(*) FROM [API].[FactWeeklyStoreDeptSales]
UNION ALL SELECT 'FactDailyFeatures', COUNT(*) FROM [API].[FactDailyFeatures]
UNION ALL SELECT 'FactDailyTargetAudit', COUNT(*) FROM [API].[FactDailyTargetAudit]
UNION ALL SELECT 'FactDailyTrainingLaborOutput', COUNT(*) FROM [API].[FactDailyTrainingLaborOutput]
UNION ALL SELECT 'FactDailyPrediction', COUNT(*) FROM [src].[FactDailyPrediction]
UNION ALL SELECT 'StgCostcoDailyAuditWide', COUNT(*) FROM [API].[StgCostcoDailyAuditWide]
UNION ALL SELECT 'ModelFeatureRegistry', COUNT(*) FROM [model].[ModelFeatureRegistry]
UNION ALL SELECT 'Notification untouched', COUNT(*) FROM [src].[Notification];
GO
