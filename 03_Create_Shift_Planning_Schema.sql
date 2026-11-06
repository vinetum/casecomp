/*
    LaunchProject - Texas MISA Fall 2026 Case Competition
    Script 03 of 06: shift-level planning schema [comp]

    Run after:
      01_Create_Database.sql
      02_Load_Core_Data.sql

    What this adds (all data is SIMULATED / MOCK, not Costco data):
      Reference / assumption tables
        [comp].[DimShift]                    three planning shifts per day (OPEN, MID, EVE)
        [comp].[ShiftDefinition]             shift times, paid hours, open/closed, minimum staff by dept and day type
        [comp].[LaborStandard]               engineered labor standard (labor hours per workload unit) by dept
        [comp].[ServiceMetricDefinition]     one service metric + target per dept
        [comp].[LaborCostAssumption]         regular / overtime cost by warehouse and dept
        [comp].[Scenario]                    HIST, BASE, PEAK, DISRUPT
      Fact tables (grain: warehouse x dept x date x shift)
        [comp].[FactShiftDemand]             historical actual workload by shift (sums to the daily transaction_count_proxy)
        [comp].[FactShiftSchedule]           historical actual schedules ('Actual') and the planning-week draft ('Draft')
        [comp].[FactShiftAvailability]       available regular / overtime / cross-trained employees, by scenario
        [comp].[FactShiftServiceLevel]       historical simulated service outcome vs. target
        [comp].[ScenarioDemandAdjustment]    planning-week demand multipliers by scenario
      Views
        [comp].[v_ShiftHistory]              one row per historical warehouse/dept/date/shift with everything joined
        [comp].[v_PlanningWeekGrid]          one row per scenario x planning-week warehouse/dept/date/shift

    [comp] tables reference the core [API] tables with foreign keys.
    Rerunnable: drops and recreates [comp] objects.
*/
SET NOCOUNT ON;
GO
USE [LaunchProject];
GO
IF SCHEMA_ID(N'comp') IS NULL EXEC(N'CREATE SCHEMA [comp]');
GO

DROP VIEW IF EXISTS [comp].[v_PlanningWeekGrid];
DROP VIEW IF EXISTS [comp].[v_ShiftHistory];
DROP TABLE IF EXISTS [comp].[ScenarioDemandAdjustment];
DROP TABLE IF EXISTS [comp].[FactShiftServiceLevel];
DROP TABLE IF EXISTS [comp].[FactShiftAvailability];
DROP TABLE IF EXISTS [comp].[FactShiftSchedule];
DROP TABLE IF EXISTS [comp].[FactShiftDemand];
DROP TABLE IF EXISTS [comp].[Scenario];
DROP TABLE IF EXISTS [comp].[LaborCostAssumption];
DROP TABLE IF EXISTS [comp].[ServiceMetricDefinition];
DROP TABLE IF EXISTS [comp].[LaborStandard];
DROP TABLE IF EXISTS [comp].[ShiftDefinition];
DROP TABLE IF EXISTS [comp].[DimShift];
GO

/* ------------------------------------------------------------------ reference / assumption tables */
CREATE TABLE [comp].[DimShift] (
    [shift_code]      NVARCHAR(10)  NOT NULL,
    [shift_name]      NVARCHAR(50)  NOT NULL,
    [shift_sequence]  TINYINT       NOT NULL,
    CONSTRAINT [PK_DimShift] PRIMARY KEY ([shift_code]),
    CONSTRAINT [UQ_DimShift_sequence] UNIQUE ([shift_sequence])
);
GO

CREATE TABLE [comp].[ShiftDefinition] (
    [dept_id]           SMALLINT      NOT NULL,
    [day_type]          NVARCHAR(10)  NOT NULL,
    [shift_code]        NVARCHAR(10)  NOT NULL,
    [shift_start_time]  TIME(0)       NULL,
    [shift_end_time]    TIME(0)       NULL,
    [paid_hours]        DECIMAL(4,2)  NOT NULL,
    [is_open]           BIT           NOT NULL,
    [min_staff]         SMALLINT      NOT NULL,
    [value_type]        NVARCHAR(30)  NOT NULL CONSTRAINT [DF_ShiftDefinition_value_type] DEFAULT (N'Assumed'),
    [notes]             NVARCHAR(400) NULL,
    CONSTRAINT [PK_ShiftDefinition] PRIMARY KEY ([dept_id], [day_type], [shift_code]),
    CONSTRAINT [FK_ShiftDefinition_DimDepartment] FOREIGN KEY ([dept_id]) REFERENCES [API].[DimDepartment] ([dept_id]),
    CONSTRAINT [FK_ShiftDefinition_DimShift] FOREIGN KEY ([shift_code]) REFERENCES [comp].[DimShift] ([shift_code]),
    CONSTRAINT [CK_ShiftDefinition_day_type] CHECK ([day_type] IN (N'Weekday', N'Saturday', N'Sunday')),
    CONSTRAINT [CK_ShiftDefinition_open_hours] CHECK (([is_open] = 1 AND [paid_hours] > 0 AND [min_staff] > 0)
                                                   OR ([is_open] = 0 AND [paid_hours] = 0 AND [min_staff] = 0))
);
GO

CREATE TABLE [comp].[LaborStandard] (
    [dept_id]                        SMALLINT      NOT NULL,
    [workload_unit_definition]       NVARCHAR(400) NOT NULL,
    [labor_hours_per_workload_unit]  DECIMAL(6,3)  NOT NULL,
    [standard_basis]                 NVARCHAR(400) NOT NULL,
    [value_type]                     NVARCHAR(30)  NOT NULL CONSTRAINT [DF_LaborStandard_value_type] DEFAULT (N'Assumed'),
    CONSTRAINT [PK_LaborStandard] PRIMARY KEY ([dept_id]),
    CONSTRAINT [FK_LaborStandard_DimDepartment] FOREIGN KEY ([dept_id]) REFERENCES [API].[DimDepartment] ([dept_id]),
    CONSTRAINT [CK_LaborStandard_positive] CHECK ([labor_hours_per_workload_unit] > 0)
);
GO

CREATE TABLE [comp].[ServiceMetricDefinition] (
    [metric_code]       NVARCHAR(30)  NOT NULL,
    [dept_id]           SMALLINT      NOT NULL,
    [metric_name]       NVARCHAR(100) NOT NULL,
    [unit_of_measure]   NVARCHAR(20)  NOT NULL,
    [target_value]      DECIMAL(8,2)  NOT NULL,
    [better_direction]  NVARCHAR(10)  NOT NULL,
    [definition]        NVARCHAR(600) NOT NULL,
    [value_type]        NVARCHAR(30)  NOT NULL CONSTRAINT [DF_ServiceMetricDefinition_value_type] DEFAULT (N'Assumed'),
    CONSTRAINT [PK_ServiceMetricDefinition] PRIMARY KEY ([metric_code]),
    CONSTRAINT [UQ_ServiceMetricDefinition_dept] UNIQUE ([dept_id]),
    CONSTRAINT [FK_ServiceMetricDefinition_DimDepartment] FOREIGN KEY ([dept_id]) REFERENCES [API].[DimDepartment] ([dept_id]),
    CONSTRAINT [CK_ServiceMetricDefinition_direction] CHECK ([better_direction] IN (N'Lower', N'Higher'))
);
GO

CREATE TABLE [comp].[LaborCostAssumption] (
    [store_id]                         SMALLINT      NOT NULL,
    [dept_id]                          SMALLINT      NOT NULL,
    [base_hourly_wage]                 DECIMAL(8,2)  NOT NULL,
    [regular_burden_pct]               DECIMAL(5,4)  NOT NULL,
    [loaded_regular_hourly_cost]       DECIMAL(8,2)  NOT NULL,
    [overtime_multiplier]              DECIMAL(4,2)  NOT NULL,
    [overtime_burden_pct]              DECIMAL(5,4)  NOT NULL,
    [loaded_overtime_hourly_cost]      DECIMAL(8,2)  NOT NULL,
    [weekly_overtime_threshold_hours]  DECIMAL(5,2)  NOT NULL,
    [effective_start_date]             DATE          NOT NULL,
    [value_type]                       NVARCHAR(30)  NOT NULL CONSTRAINT [DF_LaborCostAssumption_value_type] DEFAULT (N'Assumed'),
    [notes]                            NVARCHAR(600) NULL,
    CONSTRAINT [PK_LaborCostAssumption] PRIMARY KEY ([store_id], [dept_id]),
    CONSTRAINT [FK_LaborCostAssumption_DimStore] FOREIGN KEY ([store_id]) REFERENCES [API].[DimStore] ([store_id]),
    CONSTRAINT [FK_LaborCostAssumption_DimDepartment] FOREIGN KEY ([dept_id]) REFERENCES [API].[DimDepartment] ([dept_id]),
    CONSTRAINT [CK_LaborCostAssumption_ot_gt_reg] CHECK ([loaded_overtime_hourly_cost] > [loaded_regular_hourly_cost])
);
GO

CREATE TABLE [comp].[Scenario] (
    [scenario_id]    TINYINT        NOT NULL,
    [scenario_code]  NVARCHAR(20)   NOT NULL,
    [scenario_name]  NVARCHAR(100)  NOT NULL,
    [scenario_type]  NVARCHAR(20)   NOT NULL,
    [period_start]   DATE           NOT NULL,
    [period_end]     DATE           NOT NULL,
    [description]    NVARCHAR(1000) NOT NULL,
    [value_type]     NVARCHAR(30)   NOT NULL,
    CONSTRAINT [PK_Scenario] PRIMARY KEY ([scenario_id]),
    CONSTRAINT [UQ_Scenario_code] UNIQUE ([scenario_code]),
    CONSTRAINT [CK_Scenario_type] CHECK ([scenario_type] IN (N'Historical', N'Planning')),
    CONSTRAINT [CK_Scenario_period] CHECK ([period_end] >= [period_start])
);
GO

/* ------------------------------------------------------------------ fact tables */
CREATE TABLE [comp].[FactShiftDemand] (
    [store_id]      SMALLINT      NOT NULL,
    [dept_id]       SMALLINT      NOT NULL,
    [day_date]      DATE          NOT NULL,
    [shift_code]    NVARCHAR(10)  NOT NULL,
    [day_type]      NVARCHAR(10)  NOT NULL,
    [is_open]       BIT           NOT NULL,
    [demand_units]  DECIMAL(14,4) NOT NULL,
    [share_of_day]  DECIMAL(6,4)  NOT NULL,
    [value_type]    NVARCHAR(30)  NOT NULL CONSTRAINT [DF_FactShiftDemand_value_type] DEFAULT (N'Historical'),
    CONSTRAINT [PK_FactShiftDemand] PRIMARY KEY ([store_id], [dept_id], [day_date], [shift_code]),
    /* parent = daily demand row; shift demand sums to its transaction_count_proxy */
    CONSTRAINT [FK_FactShiftDemand_FactDailyTrainingLaborOutput] FOREIGN KEY ([store_id], [dept_id], [day_date])
        REFERENCES [API].[FactDailyTrainingLaborOutput] ([store_id], [dept_id], [day_date]),
    CONSTRAINT [FK_FactShiftDemand_ShiftDefinition] FOREIGN KEY ([dept_id], [day_type], [shift_code])
        REFERENCES [comp].[ShiftDefinition] ([dept_id], [day_type], [shift_code]),
    CONSTRAINT [CK_FactShiftDemand_nonneg] CHECK ([demand_units] >= 0)
);
GO

CREATE TABLE [comp].[FactShiftSchedule] (
    [store_id]                     SMALLINT      NOT NULL,
    [dept_id]                      SMALLINT      NOT NULL,
    [day_date]                     DATE          NOT NULL,
    [shift_code]                   NVARCHAR(10)  NOT NULL,
    [schedule_type]                NVARCHAR(10)  NOT NULL,
    [scheduled_employees]          SMALLINT      NOT NULL,
    [paid_hours_per_employee]      DECIMAL(4,2)  NOT NULL,
    [scheduled_labor_hours]        DECIMAL(8,2)  NOT NULL,
    [callout_employees]            SMALLINT      NULL,
    [backfill_employees]           SMALLINT      NULL,
    [worked_employees]             SMALLINT      NULL,
    [worked_regular_employees]     SMALLINT      NULL,
    [worked_overtime_employees]    SMALLINT      NULL,
    [worked_labor_hours]           DECIMAL(8,2)  NULL,
    [worked_regular_hours]         DECIMAL(8,2)  NULL,
    [worked_overtime_hours]        DECIMAL(8,2)  NULL,
    [value_type]                   NVARCHAR(30)  NOT NULL,
    CONSTRAINT [PK_FactShiftSchedule] PRIMARY KEY ([store_id], [dept_id], [day_date], [shift_code], [schedule_type]),
    CONSTRAINT [FK_FactShiftSchedule_DimStore] FOREIGN KEY ([store_id]) REFERENCES [API].[DimStore] ([store_id]),
    CONSTRAINT [FK_FactShiftSchedule_DimDepartment] FOREIGN KEY ([dept_id]) REFERENCES [API].[DimDepartment] ([dept_id]),
    CONSTRAINT [FK_FactShiftSchedule_DimCalendarDay] FOREIGN KEY ([day_date]) REFERENCES [API].[DimCalendarDay] ([day_date]),
    CONSTRAINT [FK_FactShiftSchedule_DimShift] FOREIGN KEY ([shift_code]) REFERENCES [comp].[DimShift] ([shift_code]),
    CONSTRAINT [CK_FactShiftSchedule_type] CHECK ([schedule_type] IN (N'Actual', N'Draft')),
    CONSTRAINT [CK_FactShiftSchedule_actual_complete] CHECK ([schedule_type] = N'Draft' OR
        ([callout_employees] IS NOT NULL AND [backfill_employees] IS NOT NULL AND [worked_employees] IS NOT NULL
         AND [worked_regular_employees] IS NOT NULL AND [worked_overtime_employees] IS NOT NULL)),
    CONSTRAINT [CK_FactShiftSchedule_worked] CHECK ([worked_employees] IS NULL OR
        [worked_employees] = [scheduled_employees] - [callout_employees] + [backfill_employees])
);
GO

CREATE TABLE [comp].[FactShiftAvailability] (
    [scenario_id]                   TINYINT       NOT NULL,
    [store_id]                      SMALLINT      NOT NULL,
    [dept_id]                       SMALLINT      NOT NULL,
    [day_date]                      DATE          NOT NULL,
    [shift_code]                    NVARCHAR(10)  NOT NULL,
    [available_regular_employees]   SMALLINT      NOT NULL,
    [max_overtime_employees]        SMALLINT      NOT NULL,
    [cross_trained_flex_employees]  SMALLINT      NOT NULL,
    [available_regular_hours]       DECIMAL(8,2)  NOT NULL,
    [max_overtime_hours]            DECIMAL(8,2)  NOT NULL,
    [availability_note]             NVARCHAR(300) NULL,
    [value_type]                    NVARCHAR(30)  NOT NULL,
    CONSTRAINT [PK_FactShiftAvailability] PRIMARY KEY ([scenario_id], [store_id], [dept_id], [day_date], [shift_code]),
    CONSTRAINT [FK_FactShiftAvailability_Scenario] FOREIGN KEY ([scenario_id]) REFERENCES [comp].[Scenario] ([scenario_id]),
    CONSTRAINT [FK_FactShiftAvailability_DimStore] FOREIGN KEY ([store_id]) REFERENCES [API].[DimStore] ([store_id]),
    CONSTRAINT [FK_FactShiftAvailability_DimDepartment] FOREIGN KEY ([dept_id]) REFERENCES [API].[DimDepartment] ([dept_id]),
    CONSTRAINT [FK_FactShiftAvailability_DimCalendarDay] FOREIGN KEY ([day_date]) REFERENCES [API].[DimCalendarDay] ([day_date]),
    CONSTRAINT [FK_FactShiftAvailability_DimShift] FOREIGN KEY ([shift_code]) REFERENCES [comp].[DimShift] ([shift_code]),
    CONSTRAINT [CK_FactShiftAvailability_nonneg] CHECK ([available_regular_employees] >= 0 AND [max_overtime_employees] >= 0 AND [cross_trained_flex_employees] >= 0)
);
GO

CREATE TABLE [comp].[FactShiftServiceLevel] (
    [store_id]      SMALLINT      NOT NULL,
    [dept_id]       SMALLINT      NOT NULL,
    [day_date]      DATE          NOT NULL,
    [shift_code]    NVARCHAR(10)  NOT NULL,
    [metric_code]   NVARCHAR(30)  NOT NULL,
    [metric_value]  DECIMAL(8,1)  NULL,
    [target_value]  DECIMAL(8,2)  NOT NULL,
    [met_target]    BIT           NULL,
    [value_type]    NVARCHAR(30)  NOT NULL CONSTRAINT [DF_FactShiftServiceLevel_value_type] DEFAULT (N'Historical (simulated)'),
    CONSTRAINT [PK_FactShiftServiceLevel] PRIMARY KEY ([store_id], [dept_id], [day_date], [shift_code]),
    CONSTRAINT [FK_FactShiftServiceLevel_FactShiftDemand] FOREIGN KEY ([store_id], [dept_id], [day_date], [shift_code])
        REFERENCES [comp].[FactShiftDemand] ([store_id], [dept_id], [day_date], [shift_code]),
    CONSTRAINT [FK_FactShiftServiceLevel_ServiceMetricDefinition] FOREIGN KEY ([metric_code])
        REFERENCES [comp].[ServiceMetricDefinition] ([metric_code]),
    CONSTRAINT [CK_FactShiftServiceLevel_met] CHECK (([metric_value] IS NULL AND [met_target] IS NULL)
        OR ([metric_value] IS NOT NULL AND [met_target] = CASE WHEN [metric_value] <= [target_value] THEN 1 ELSE 0 END))
);
GO

CREATE TABLE [comp].[ScenarioDemandAdjustment] (
    [scenario_id]        TINYINT       NOT NULL,
    [store_id]           SMALLINT      NOT NULL,
    [dept_id]            SMALLINT      NOT NULL,
    [day_date]           DATE          NOT NULL,
    [shift_code]         NVARCHAR(10)  NOT NULL,
    [demand_multiplier]  DECIMAL(5,2)  NOT NULL,
    [adjustment_reason]  NVARCHAR(300) NOT NULL,
    [value_type]         NVARCHAR(30)  NOT NULL CONSTRAINT [DF_ScenarioDemandAdjustment_value_type] DEFAULT (N'Scenario-generated'),
    CONSTRAINT [PK_ScenarioDemandAdjustment] PRIMARY KEY ([scenario_id], [store_id], [dept_id], [day_date], [shift_code]),
    CONSTRAINT [FK_ScenarioDemandAdjustment_Scenario] FOREIGN KEY ([scenario_id]) REFERENCES [comp].[Scenario] ([scenario_id]),
    CONSTRAINT [FK_ScenarioDemandAdjustment_DimStore] FOREIGN KEY ([store_id]) REFERENCES [API].[DimStore] ([store_id]),
    CONSTRAINT [FK_ScenarioDemandAdjustment_DimDepartment] FOREIGN KEY ([dept_id]) REFERENCES [API].[DimDepartment] ([dept_id]),
    CONSTRAINT [FK_ScenarioDemandAdjustment_DimCalendarDay] FOREIGN KEY ([day_date]) REFERENCES [API].[DimCalendarDay] ([day_date]),
    CONSTRAINT [FK_ScenarioDemandAdjustment_DimShift] FOREIGN KEY ([shift_code]) REFERENCES [comp].[DimShift] ([shift_code]),
    CONSTRAINT [CK_ScenarioDemandAdjustment_mult] CHECK ([demand_multiplier] > 0)
);
GO

CREATE INDEX [IX_FactShiftSchedule_day] ON [comp].[FactShiftSchedule] ([day_date], [schedule_type]);
CREATE INDEX [IX_FactShiftAvailability_day] ON [comp].[FactShiftAvailability] ([day_date], [scenario_id]);
GO

/* ------------------------------------------------------------------ views */
CREATE VIEW [comp].[v_ShiftHistory]
AS
/* One row per historical warehouse x department x date x shift (1,134 rows). Export this to CSV/Excel for teams. */
SELECT
    d.[store_id],
    s.[store_size_category],
    d.[dept_id],
    dp.[department_group],
    d.[day_date],
    c.[week_start_date],
    c.[week_of_year],
    c.[day_name],
    c.[day_of_week],
    d.[day_type],
    c.[is_weekend],
    c.[is_holiday],
    h.[holiday_window_role],
    h.[is_costco_closed],
    f.[temperature],
    f.[has_promotion],
    d.[shift_code],
    sh.[shift_sequence],
    sd.[shift_start_time],
    sd.[shift_end_time],
    sd.[paid_hours],
    d.[is_open],
    sd.[min_staff],
    tl.[transaction_count_proxy]            AS [daily_demand_units],
    d.[demand_units]                        AS [shift_demand_units],
    d.[share_of_day]                        AS [shift_share_of_day],
    sc.[scheduled_employees],
    sc.[scheduled_labor_hours],
    sc.[callout_employees],
    sc.[backfill_employees],
    sc.[worked_employees],
    sc.[worked_regular_employees],
    sc.[worked_overtime_employees],
    sc.[worked_labor_hours],
    sc.[worked_regular_hours],
    sc.[worked_overtime_hours],
    av.[available_regular_employees],
    av.[max_overtime_employees],
    av.[cross_trained_flex_employees],
    av.[availability_note],
    CAST(sc.[worked_regular_hours] * lc.[loaded_regular_hourly_cost]
       + sc.[worked_overtime_hours] * lc.[loaded_overtime_hourly_cost] AS DECIMAL(12,2)) AS [labor_cost],
    sl.[metric_code],
    sl.[metric_value],
    sl.[target_value],
    sl.[met_target]
FROM [comp].[FactShiftDemand] AS d
INNER JOIN [API].[DimStore] AS s ON s.[store_id] = d.[store_id]
INNER JOIN [API].[DimDepartment] AS dp ON dp.[dept_id] = d.[dept_id]
INNER JOIN [API].[DimCalendarDay] AS c ON c.[day_date] = d.[day_date]
INNER JOIN [API].[DimHolidayDay] AS h ON h.[day_date] = d.[day_date]
INNER JOIN [API].[FactDailyFeatures] AS f ON f.[store_id] = d.[store_id] AND f.[dept_id] = d.[dept_id] AND f.[day_date] = d.[day_date]
INNER JOIN [API].[FactDailyTrainingLaborOutput] AS tl ON tl.[store_id] = d.[store_id] AND tl.[dept_id] = d.[dept_id] AND tl.[day_date] = d.[day_date]
INNER JOIN [comp].[DimShift] AS sh ON sh.[shift_code] = d.[shift_code]
INNER JOIN [comp].[ShiftDefinition] AS sd ON sd.[dept_id] = d.[dept_id] AND sd.[day_type] = d.[day_type] AND sd.[shift_code] = d.[shift_code]
INNER JOIN [comp].[FactShiftSchedule] AS sc ON sc.[store_id] = d.[store_id] AND sc.[dept_id] = d.[dept_id] AND sc.[day_date] = d.[day_date]
                                           AND sc.[shift_code] = d.[shift_code] AND sc.[schedule_type] = N'Actual'
INNER JOIN [comp].[FactShiftAvailability] AS av ON av.[scenario_id] = 0 AND av.[store_id] = d.[store_id] AND av.[dept_id] = d.[dept_id]
                                               AND av.[day_date] = d.[day_date] AND av.[shift_code] = d.[shift_code]
INNER JOIN [comp].[LaborCostAssumption] AS lc ON lc.[store_id] = d.[store_id] AND lc.[dept_id] = d.[dept_id]
INNER JOIN [comp].[FactShiftServiceLevel] AS sl ON sl.[store_id] = d.[store_id] AND sl.[dept_id] = d.[dept_id]
                                               AND sl.[day_date] = d.[day_date] AND sl.[shift_code] = d.[shift_code];
GO

CREATE VIEW [comp].[v_PlanningWeekGrid]
AS
/* One row per scenario x planning-week warehouse x department x date x shift (3 x 189 = 567 rows).
   Demand is intentionally NOT included: teams forecast it. */
SELECT
    sa.[scenario_id],
    sn.[scenario_code],
    sa.[store_id],
    s.[store_size_category],
    sa.[dept_id],
    dp.[department_group],
    sa.[day_date],
    c.[day_name],
    c.[day_of_week],
    sd.[day_type],
    c.[is_weekend],
    c.[is_holiday],
    h.[holiday_name],
    h.[holiday_window_role],
    h.[is_pre_holiday_stockup],
    h.[is_post_holiday_rebound],
    f.[temperature],
    f.[has_promotion],
    f.[promotion_index],
    sa.[shift_code],
    sd.[shift_start_time],
    sd.[shift_end_time],
    sd.[paid_hours],
    sd.[is_open],
    sd.[min_staff],
    sa.[demand_multiplier],
    sa.[adjustment_reason],
    dr.[scheduled_employees]                AS [draft_scheduled_employees],
    dr.[scheduled_labor_hours]              AS [draft_scheduled_labor_hours],
    av.[available_regular_employees],
    av.[max_overtime_employees],
    av.[cross_trained_flex_employees],
    av.[availability_note],
    lc.[loaded_regular_hourly_cost],
    lc.[loaded_overtime_hourly_cost],
    smd.[metric_code],
    smd.[target_value]                      AS [service_target_value]
FROM [comp].[ScenarioDemandAdjustment] AS sa
INNER JOIN [comp].[Scenario] AS sn ON sn.[scenario_id] = sa.[scenario_id]
INNER JOIN [API].[DimStore] AS s ON s.[store_id] = sa.[store_id]
INNER JOIN [API].[DimDepartment] AS dp ON dp.[dept_id] = sa.[dept_id]
INNER JOIN [API].[DimCalendarDay] AS c ON c.[day_date] = sa.[day_date]
INNER JOIN [API].[DimHolidayDay] AS h ON h.[day_date] = sa.[day_date]
INNER JOIN [API].[FactDailyFeatures] AS f ON f.[store_id] = sa.[store_id] AND f.[dept_id] = sa.[dept_id] AND f.[day_date] = sa.[day_date]
INNER JOIN [comp].[ShiftDefinition] AS sd ON sd.[dept_id] = sa.[dept_id] AND sd.[shift_code] = sa.[shift_code]
       AND sd.[day_type] = CASE c.[day_of_week] WHEN 6 THEN N'Saturday' WHEN 7 THEN N'Sunday' ELSE N'Weekday' END
INNER JOIN [comp].[FactShiftSchedule] AS dr ON dr.[store_id] = sa.[store_id] AND dr.[dept_id] = sa.[dept_id] AND dr.[day_date] = sa.[day_date]
                                           AND dr.[shift_code] = sa.[shift_code] AND dr.[schedule_type] = N'Draft'
INNER JOIN [comp].[FactShiftAvailability] AS av ON av.[scenario_id] = sa.[scenario_id] AND av.[store_id] = sa.[store_id]
                                               AND av.[dept_id] = sa.[dept_id] AND av.[day_date] = sa.[day_date] AND av.[shift_code] = sa.[shift_code]
INNER JOIN [comp].[LaborCostAssumption] AS lc ON lc.[store_id] = sa.[store_id] AND lc.[dept_id] = sa.[dept_id]
INNER JOIN [comp].[ServiceMetricDefinition] AS smd ON smd.[dept_id] = sa.[dept_id];
GO

PRINT 'Competition schema [comp] created.';
GO
