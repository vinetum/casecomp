/*
    LaunchProject - Full Database Create Script With CRUD Stored Procedures

    Purpose:
      One runnable SQL Server script for developer-local setup.

    This script includes:
      1. Database creation: [LaunchProject]
      2. Schemas: [API], [src], [model]
      3. Tables, views, and base relationships

    Notes:
      - This script does not insert mock/seed data.
      - Run the Costco-like seed script separately after this if you want sample data.
      - The script is intended for SQL Server / SSMS / Azure Data Studio / VS Code SQL Server extension.
*/

SET NOCOUNT ON;
GO

PRINT '===== LaunchProject full database build starting =====';
GO

/*
LaunchProject database build script
Generated from costco_oop_normalized_data_dictionary.xlsx
Purpose: developer-local schema creation for SQL Server / SSMS.
Note: This script is rerunnable and rebuilds the listed objects. It drops existing objects with the same names.
*/
SET NOCOUNT ON;
GO

IF DB_ID(N'LaunchProject') IS NULL
BEGIN
    CREATE DATABASE [LaunchProject];
END
GO

USE [LaunchProject];
GO

IF SCHEMA_ID(N'src') IS NULL
    EXEC(N'CREATE SCHEMA [src]');
GO

IF SCHEMA_ID(N'API') IS NULL
    EXEC(N'CREATE SCHEMA [API]');
GO

IF SCHEMA_ID(N'model') IS NULL
    EXEC(N'CREATE SCHEMA [model]');
GO

/* Drop shift-planning objects first; they reference [API] tables. Safe if they do not exist. */
IF OBJECT_ID(N'[comp].[v_PlanningWeekGrid]', N'V') IS NOT NULL DROP VIEW [comp].[v_PlanningWeekGrid];
IF OBJECT_ID(N'[comp].[v_ShiftHistory]', N'V') IS NOT NULL DROP VIEW [comp].[v_ShiftHistory];
IF OBJECT_ID(N'[comp].[ScenarioDemandAdjustment]', N'U') IS NOT NULL DROP TABLE [comp].[ScenarioDemandAdjustment];
IF OBJECT_ID(N'[comp].[FactShiftServiceLevel]', N'U') IS NOT NULL DROP TABLE [comp].[FactShiftServiceLevel];
IF OBJECT_ID(N'[comp].[FactShiftAvailability]', N'U') IS NOT NULL DROP TABLE [comp].[FactShiftAvailability];
IF OBJECT_ID(N'[comp].[FactShiftSchedule]', N'U') IS NOT NULL DROP TABLE [comp].[FactShiftSchedule];
IF OBJECT_ID(N'[comp].[FactShiftDemand]', N'U') IS NOT NULL DROP TABLE [comp].[FactShiftDemand];
IF OBJECT_ID(N'[comp].[Scenario]', N'U') IS NOT NULL DROP TABLE [comp].[Scenario];
IF OBJECT_ID(N'[comp].[LaborCostAssumption]', N'U') IS NOT NULL DROP TABLE [comp].[LaborCostAssumption];
IF OBJECT_ID(N'[comp].[ServiceMetricDefinition]', N'U') IS NOT NULL DROP TABLE [comp].[ServiceMetricDefinition];
IF OBJECT_ID(N'[comp].[LaborStandard]', N'U') IS NOT NULL DROP TABLE [comp].[LaborStandard];
IF OBJECT_ID(N'[comp].[ShiftDefinition]', N'U') IS NOT NULL DROP TABLE [comp].[ShiftDefinition];
IF OBJECT_ID(N'[comp].[DimShift]', N'U') IS NOT NULL DROP TABLE [comp].[DimShift];
GO

/* Drop views first because they depend on base tables. */
DROP VIEW IF EXISTS [API].[v_final_predictions_output];
GO

DROP VIEW IF EXISTS [API].[v_ebm_train_features_model_only];
GO

DROP VIEW IF EXISTS [API].[v_ebm_test_features_model_only];
GO

/* Drop tables in dependency order so the script can be rerun cleanly. */
DROP TABLE IF EXISTS [src].[FactDailyPrediction];
GO

DROP TABLE IF EXISTS [API].[FactDailyTrainingLaborOutput];
GO

DROP TABLE IF EXISTS [API].[FactDailyTargetAudit];
GO

DROP TABLE IF EXISTS [API].[FactDailyFeatures];
GO

DROP TABLE IF EXISTS [API].[FactWeeklyStoreDeptSales];
GO

DROP TABLE IF EXISTS [API].[DimHolidayDay];
GO

DROP TABLE IF EXISTS [API].[StgCostcoDailyAuditWide];
GO

DROP TABLE IF EXISTS [model].[ModelFeatureRegistry];
GO

DROP TABLE IF EXISTS [API].[TrafficThresholdRule];
GO

DROP TABLE IF EXISTS [API].[LaborBandRule];
GO

DROP TABLE IF EXISTS [model].[ModelRun];
GO

DROP TABLE IF EXISTS [src].[Notification];
GO

DROP TABLE IF EXISTS [API].[Employee];
GO

DROP TABLE IF EXISTS [API].[DimCalendarDay];
GO

DROP TABLE IF EXISTS [API].[DimDepartment];
GO

DROP TABLE IF EXISTS [API].[DimStore];
GO

/* Create tables. */
CREATE TABLE [API].[DimStore] (
    [store_id] SMALLINT NOT NULL,
    [store_type] NVARCHAR(255) NULL,
    [store_size] INT NULL,
    [store_size_category] NVARCHAR(255) NULL,
    [created_at] DATETIME2(7) CONSTRAINT [DF_DimStore_created_at] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    [updated_at] DATETIME2(7) CONSTRAINT [DF_DimStore_updated_at] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_DimStore] PRIMARY KEY CLUSTERED ([store_id])
);
GO

CREATE TABLE [API].[DimDepartment] (
    [dept_id] SMALLINT NOT NULL,
    [department_group] NVARCHAR(255) NOT NULL,
    [holiday_department_profile] NVARCHAR(255) NULL,
    [created_at] DATETIME2(7) CONSTRAINT [DF_DimDepartment_created_at] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    [updated_at] DATETIME2(7) CONSTRAINT [DF_DimDepartment_updated_at] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_DimDepartment] PRIMARY KEY CLUSTERED ([dept_id])
);
GO

CREATE TABLE [API].[DimCalendarDay] (
    [day_date] DATE NOT NULL,
    [week_start_date] DATE NOT NULL,
    [day_of_week] SMALLINT NOT NULL,
    [day_name] NVARCHAR(255) NOT NULL,
    [month] SMALLINT NOT NULL,
    [quarter] SMALLINT NOT NULL,
    [week_of_year] SMALLINT NOT NULL,
    [is_weekend] BIT CONSTRAINT [DF_DimCalendarDay_is_weekend] DEFAULT (0) NOT NULL,
    [is_holiday] BIT CONSTRAINT [DF_DimCalendarDay_is_holiday] DEFAULT (0) NOT NULL,
    [created_at] DATETIME2(7) CONSTRAINT [DF_DimCalendarDay_created_at] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_DimCalendarDay] PRIMARY KEY CLUSTERED ([day_date])
);
GO

CREATE TABLE [API].[DimHolidayDay] (
    [day_date] DATE NOT NULL,
    [holiday_name] NVARCHAR(255) NULL,
    [holiday_type] NVARCHAR(255) NULL,
    [related_holiday_name] NVARCHAR(255) NULL,
    [related_holiday_type] NVARCHAR(255) NULL,
    [holiday_window_role] NVARCHAR(255) NOT NULL,
    [days_to_related_holiday] INT NOT NULL,
    [days_since_related_holiday] INT NOT NULL,
    [holiday_grocery_intensity] DECIMAL(5,4) NOT NULL,
    [holiday_gift_intensity] DECIMAL(5,4) NOT NULL,
    [holiday_cookout_intensity] DECIMAL(5,4) NOT NULL,
    [holiday_stockup_window_length] INT NOT NULL,
    [holiday_day_of_week] NVARCHAR(255) NULL,
    [is_black_friday_period] BIT CONSTRAINT [DF_DimHolidayDay_is_black_friday_period] DEFAULT (0) NOT NULL,
    [is_december_holiday_season] BIT CONSTRAINT [DF_DimHolidayDay_is_december_holiday_season] DEFAULT (0) NOT NULL,
    [is_costco_closed] BIT CONSTRAINT [DF_DimHolidayDay_is_costco_closed] DEFAULT (0) NOT NULL,
    [days_to_next_costco_closure] INT NOT NULL,
    [days_since_last_costco_closure] INT NOT NULL,
    [is_pre_holiday_stockup] BIT CONSTRAINT [DF_DimHolidayDay_is_pre_holiday_stockup] DEFAULT (0) NOT NULL,
    [is_post_holiday_rebound] BIT CONSTRAINT [DF_DimHolidayDay_is_post_holiday_rebound] DEFAULT (0) NOT NULL,
    CONSTRAINT [PK_DimHolidayDay] PRIMARY KEY CLUSTERED ([day_date])
);
GO

CREATE TABLE [model].[ModelRun] (
    [model_run_id] BIGINT NOT NULL,
    [model_name] NVARCHAR(255) NOT NULL,
    [model_version] NVARCHAR(255) NULL,
    [model_algorithm] NVARCHAR(255) NULL,
    [trained_at] DATETIME2(7) CONSTRAINT [DF_ModelRun_trained_at] DEFAULT (SYSUTCDATETIME()) NULL,
    [scored_at] DATETIME2(7) CONSTRAINT [DF_ModelRun_scored_at] DEFAULT (SYSUTCDATETIME()) NULL,
    [training_data_start] DATE NULL,
    [training_data_end] DATE NULL,
    [scoring_data_start] DATE NULL,
    [scoring_data_end] DATE NULL,
    [feature_set_name] NVARCHAR(255) NULL,
    [notes] NVARCHAR(MAX) NULL,
    [created_at] DATETIME2(7) CONSTRAINT [DF_ModelRun_created_at] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_ModelRun] PRIMARY KEY CLUSTERED ([model_run_id])
);
GO

CREATE TABLE [API].[LaborBandRule] (
    [recommended_labor_band_code] SMALLINT NOT NULL,
    [recommended_labor_band] NVARCHAR(100) NOT NULL,
    [busyness_band] NVARCHAR(255) NOT NULL,
    [min_traffic_index] DECIMAL(5,2) NULL,
    [max_traffic_index] DECIMAL(5,2) NULL,
    [description] NVARCHAR(MAX) NULL,
    CONSTRAINT [PK_LaborBandRule] PRIMARY KEY CLUSTERED ([recommended_labor_band_code]),
    CONSTRAINT [UQ_LaborBandRule_recommended_labor_band] UNIQUE ([recommended_labor_band])
);
GO

CREATE TABLE [API].[TrafficThresholdRule] (
    [store_size_category] NVARCHAR(100) NOT NULL,
    [poc_department_group] NVARCHAR(100) NOT NULL,
    [very_low_max_transactions] DECIMAL(14,4) NULL,
    [low_max_transactions] DECIMAL(14,4) NULL,
    [standard_max_transactions] DECIMAL(14,4) NULL,
    [high_max_transactions] DECIMAL(14,4) NULL,
    [peak_min_transactions] DECIMAL(14,4) NULL,
    [effective_start_date] DATE NOT NULL,
    [effective_end_date] DATE NULL,
    [notes] NVARCHAR(MAX) NULL,
    CONSTRAINT [PK_TrafficThresholdRule] PRIMARY KEY CLUSTERED ([store_size_category], [poc_department_group], [effective_start_date])
);
GO

CREATE TABLE [model].[ModelFeatureRegistry] (
    [column_name] NVARCHAR(100) NOT NULL,
    [variable_group] NVARCHAR(255) NULL,
    [poc_role] NVARCHAR(255) NULL,
    [data_type] NVARCHAR(255) NULL,
    [business_meaning] NVARCHAR(MAX) NULL,
    [source_or_derivation] NVARCHAR(MAX) NULL,
    [use_in_ebm_busyness_model] NVARCHAR(255) NULL,
    [ebm_model_treatment] NVARCHAR(255) NULL,
    [use_in_post_model_labor_rules] NVARCHAR(255) NULL,
    [business_rule_use] NVARCHAR(MAX) NULL,
    [leakage_risk] NVARCHAR(255) NULL,
    [in_full_train_audit_file] BIT NULL,
    [in_full_test_scoring_features_file] BIT NULL,
    [in_ebm_train_model_only_file] BIT NULL,
    [in_ebm_test_model_only_file] BIT NULL,
    [expected_final_output_field] BIT NULL,
    [train_profile] NVARCHAR(MAX) NULL,
    [test_profile] NVARCHAR(MAX) NULL,
    [missing_or_none_handling] NVARCHAR(MAX) NULL,
    [recommended_preprocessing] NVARCHAR(MAX) NULL,
    [notes] NVARCHAR(MAX) NULL,
    [loaded_at] DATETIME2(7) CONSTRAINT [DF_ModelFeatureRegistry_loaded_at] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_ModelFeatureRegistry] PRIMARY KEY CLUSTERED ([column_name])
);
GO

CREATE TABLE [API].[StgCostcoDailyAuditWide] (
    [store_id] SMALLINT NULL,
    [dept_id] SMALLINT NULL,
    [poc_department_group] NVARCHAR(255) NULL,
    [store_type] NVARCHAR(255) NULL,
    [store_size] INT NULL,
    [store_size_category] NVARCHAR(255) NULL,
    [weekly_sales] DECIMAL(14,2) NULL,
    [temperature] DECIMAL(8,3) NULL,
    [fuel_price] DECIMAL(8,4) NULL,
    [markdown1] DECIMAL(14,2) NULL,
    [markdown2] DECIMAL(14,2) NULL,
    [markdown3] DECIMAL(14,2) NULL,
    [markdown4] DECIMAL(14,2) NULL,
    [markdown5] DECIMAL(14,2) NULL,
    [cpi] DECIMAL(10,4) NULL,
    [unemployment] DECIMAL(6,3) NULL,
    [is_holiday] BIT CONSTRAINT [DF_StgCostcoDailyAuditWide_is_holiday] DEFAULT (0) NULL,
    [week_start_date] DATE NULL,
    [day_date] DATE NULL,
    [day_of_week] SMALLINT NULL,
    [day_name] NVARCHAR(255) NULL,
    [holiday_name] NVARCHAR(255) NULL,
    [holiday_type] NVARCHAR(255) NULL,
    [related_holiday_name] NVARCHAR(255) NULL,
    [related_holiday_type] NVARCHAR(255) NULL,
    [holiday_window_role] NVARCHAR(255) NULL,
    [days_to_related_holiday] INT NULL,
    [days_since_related_holiday] INT NULL,
    [holiday_grocery_intensity] DECIMAL(5,4) NULL,
    [holiday_gift_intensity] DECIMAL(5,4) NULL,
    [holiday_cookout_intensity] DECIMAL(5,4) NULL,
    [holiday_stockup_window_length] INT NULL,
    [holiday_day_of_week] NVARCHAR(255) NULL,
    [is_black_friday_period] BIT CONSTRAINT [DF_StgCostcoDailyAuditWide_is_black_friday_period] DEFAULT (0) NULL,
    [is_december_holiday_season] BIT CONSTRAINT [DF_StgCostcoDailyAuditWide_is_december_holiday_season] DEFAULT (0) NULL,
    [holiday_department_profile] NVARCHAR(255) NULL,
    [department_holiday_impact_factor] DECIMAL(12,6) NULL,
    [is_costco_closed] BIT CONSTRAINT [DF_StgCostcoDailyAuditWide_is_costco_closed] DEFAULT (0) NULL,
    [days_to_next_costco_closure] INT NULL,
    [days_since_last_costco_closure] INT NULL,
    [is_pre_holiday_stockup] BIT CONSTRAINT [DF_StgCostcoDailyAuditWide_is_pre_holiday_stockup] DEFAULT (0) NULL,
    [is_post_holiday_rebound] BIT CONSTRAINT [DF_StgCostcoDailyAuditWide_is_post_holiday_rebound] DEFAULT (0) NULL,
    [is_weekend] BIT CONSTRAINT [DF_StgCostcoDailyAuditWide_is_weekend] DEFAULT (0) NULL,
    [month] SMALLINT NULL,
    [quarter] SMALLINT NULL,
    [week_of_year] SMALLINT NULL,
    [base_daily_weight] DECIMAL(12,8) NULL,
    [holiday_adjustment_factor] DECIMAL(12,6) NULL,
    [adjusted_daily_weight] DECIMAL(12,8) NULL,
    [daily_weight] DECIMAL(12,8) NULL,
    [promotion_index] DECIMAL(14,4) NULL,
    [has_promotion] BIT NULL,
    [daily_promotion_index] DECIMAL(14,4) NULL,
    [temperature_category] NVARCHAR(255) NULL,
    [daily_sales_proxy] DECIMAL(14,2) NULL,
    [busyness_proxy] DECIMAL(14,2) NULL,
    [average_ticket_proxy] DECIMAL(12,2) NULL,
    [transaction_count_proxy] DECIMAL(14,4) NULL,
    [traffic_index] DECIMAL(5,2) NULL,
    [busyness_band] NVARCHAR(255) NULL,
    [labor_planning_context] NVARCHAR(255) NULL,
    [recommended_labor_band] NVARCHAR(255) NULL,
    [recommended_labor_band_code] SMALLINT NULL,
    [labor_rule_reason] NVARCHAR(MAX) NULL,
    [predicted_busyness_proxy] DECIMAL(14,2) NULL,
    [predicted_transaction_count_proxy] DECIMAL(14,4) NULL,
    [predicted_traffic_index] DECIMAL(5,2) NULL,
    [predicted_busyness_band] NVARCHAR(255) NULL,
    [predicted_labor_planning_context] NVARCHAR(255) NULL,
    [predicted_recommended_labor_band] NVARCHAR(255) NULL,
    [predicted_recommended_labor_band_code] SMALLINT NULL,
    [predicted_labor_rule_reason] NVARCHAR(MAX) NULL,
    [loaded_at] DATETIME2(7) CONSTRAINT [DF_StgCostcoDailyAuditWide_loaded_at] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    [source_file_name] NVARCHAR(255) NULL
);
GO

CREATE TABLE [src].[Notification] (
    [state] NVARCHAR(100) NOT NULL,
    [createdUTC] DATETIME2(7) CONSTRAINT [DF_Notification_createdUTC] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    [modifiedUTC] DATETIME2(7) CONSTRAINT [DF_Notification_modifiedUTC] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    [recomendation] NVARCHAR(MAX) NOT NULL,
    [reasoning] NVARCHAR(MAX) NOT NULL,
    [Accepted] BIT NOT NULL
);
GO

CREATE TABLE [API].[Employee] (
    [ID] SMALLINT NOT NULL,
    [name] NVARCHAR(MAX) NOT NULL,
    [DepartmentIds] NVARCHAR(MAX) NOT NULL,
    [storeIds] NVARCHAR(MAX) NOT NULL,
    [role] NVARCHAR(50) NOT NULL,
    [availableHours] FLOAT NOT NULL,
    CONSTRAINT [CK_Employee_DepartmentIds_IsJson] CHECK ([DepartmentIds] IS NULL OR ISJSON([DepartmentIds]) = 1),
    CONSTRAINT [CK_Employee_storeIds_IsJson] CHECK ([storeIds] IS NULL OR ISJSON([storeIds]) = 1)
);
GO

CREATE TABLE [API].[FactWeeklyStoreDeptSales] (
    [store_id] SMALLINT NOT NULL,
    [dept_id] SMALLINT NOT NULL,
    [week_start_date] DATE NOT NULL,
    [weekly_sales] DECIMAL(14,2) NULL,
    [source_file_name] NVARCHAR(255) NULL,
    [loaded_at] DATETIME2(7) CONSTRAINT [DF_FactWeeklyStoreDeptSales_loaded_at] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_FactWeeklyStoreDeptSales] PRIMARY KEY CLUSTERED ([store_id], [dept_id], [week_start_date])
);
GO

CREATE TABLE [API].[FactDailyFeatures] (
    [store_id] SMALLINT NOT NULL,
    [dept_id] SMALLINT NOT NULL,
    [day_date] DATE NOT NULL,
    [dataset_partition] NVARCHAR(255) NULL,
    [temperature] DECIMAL(8,3) NULL,
    [fuel_price] DECIMAL(8,4) NULL,
    [markdown1] DECIMAL(14,2) NULL,
    [markdown2] DECIMAL(14,2) NULL,
    [markdown3] DECIMAL(14,2) NULL,
    [markdown4] DECIMAL(14,2) NULL,
    [markdown5] DECIMAL(14,2) NULL,
    [cpi] DECIMAL(10,4) NULL,
    [unemployment] DECIMAL(6,3) NULL,
    [temperature_category] NVARCHAR(255) NULL,
    [promotion_index] DECIMAL(14,4) NOT NULL,
    [has_promotion] BIT NOT NULL,
    [department_holiday_impact_factor] DECIMAL(12,6) NULL,
    [average_ticket_proxy] DECIMAL(12,2) NULL,
    [source_file_name] NVARCHAR(255) NULL,
    [loaded_at] DATETIME2(7) CONSTRAINT [DF_FactDailyFeatures_loaded_at] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_FactDailyFeatures] PRIMARY KEY CLUSTERED ([store_id], [dept_id], [day_date])
);
GO

CREATE TABLE [API].[FactDailyTargetAudit] (
    [store_id] SMALLINT NOT NULL,
    [dept_id] SMALLINT NOT NULL,
    [day_date] DATE NOT NULL,
    [weekly_sales] DECIMAL(14,2) NULL,
    [base_daily_weight] DECIMAL(12,8) NULL,
    [holiday_adjustment_factor] DECIMAL(12,6) NULL,
    [adjusted_daily_weight] DECIMAL(12,8) NULL,
    [daily_weight] DECIMAL(12,8) NULL,
    [daily_promotion_index] DECIMAL(14,4) NULL,
    [daily_sales_proxy] DECIMAL(14,2) NULL,
    [busyness_proxy] DECIMAL(14,2) NULL,
    [created_at] DATETIME2(7) CONSTRAINT [DF_FactDailyTargetAudit_created_at] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_FactDailyTargetAudit] PRIMARY KEY CLUSTERED ([store_id], [dept_id], [day_date])
);
GO

CREATE TABLE [API].[FactDailyTrainingLaborOutput] (
    [store_id] SMALLINT NOT NULL,
    [dept_id] SMALLINT NOT NULL,
    [day_date] DATE NOT NULL,
    [transaction_count_proxy] DECIMAL(14,4) NULL,
    [traffic_index] DECIMAL(5,2) NULL,
    [busyness_band] NVARCHAR(255) NULL,
    [labor_planning_context] NVARCHAR(255) NULL,
    [recommended_labor_band] NVARCHAR(255) NULL,
    [recommended_labor_band_code] SMALLINT NULL,
    [labor_rule_reason] NVARCHAR(MAX) NULL,
    [created_at] DATETIME2(7) CONSTRAINT [DF_FactDailyTrainingLaborOutput_created_at] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_FactDailyTrainingLaborOutput] PRIMARY KEY CLUSTERED ([store_id], [dept_id], [day_date])
);
GO

CREATE TABLE [src].[FactDailyPrediction] (
    [model_run_id] BIGINT NOT NULL,
    [store_id] SMALLINT NOT NULL,
    [dept_id] SMALLINT NOT NULL,
    [day_date] DATE NOT NULL,
    [predicted_busyness_proxy] DECIMAL(14,2) NULL,
    [predicted_transaction_count_proxy] DECIMAL(14,4) NULL,
    [predicted_traffic_index] DECIMAL(5,2) NULL,
    [predicted_busyness_band] NVARCHAR(255) NULL,
    [predicted_labor_planning_context] NVARCHAR(255) NULL,
    [predicted_recommended_labor_band] NVARCHAR(255) NULL,
    [predicted_recommended_labor_band_code] SMALLINT NULL,
    [predicted_labor_rule_reason] NVARCHAR(MAX) NULL,
    [inserted_at] DATETIME2(7) CONSTRAINT [DF_FactDailyPrediction_inserted_at] DEFAULT (SYSUTCDATETIME()) NOT NULL,
    CONSTRAINT [PK_FactDailyPrediction] PRIMARY KEY CLUSTERED ([model_run_id], [store_id], [dept_id], [day_date])
);
GO

/* Create foreign key relationships from the Relationships sheet. */
ALTER TABLE [API].[DimHolidayDay] WITH CHECK ADD CONSTRAINT [FK_DimHolidayDay_DimCalendarDay_day_date] FOREIGN KEY ([day_date])
    REFERENCES [API].[DimCalendarDay] ([day_date]);
GO
ALTER TABLE [API].[DimHolidayDay] CHECK CONSTRAINT [FK_DimHolidayDay_DimCalendarDay_day_date];
GO

ALTER TABLE [API].[FactWeeklyStoreDeptSales] WITH CHECK ADD CONSTRAINT [FK_FactWeeklyStoreDeptSales_DimStore_store_id] FOREIGN KEY ([store_id])
    REFERENCES [API].[DimStore] ([store_id]);
GO
ALTER TABLE [API].[FactWeeklyStoreDeptSales] CHECK CONSTRAINT [FK_FactWeeklyStoreDeptSales_DimStore_store_id];
GO

ALTER TABLE [API].[FactWeeklyStoreDeptSales] WITH CHECK ADD CONSTRAINT [FK_FactWeeklyStoreDeptSales_DimDepartment_dept_id] FOREIGN KEY ([dept_id])
    REFERENCES [API].[DimDepartment] ([dept_id]);
GO
ALTER TABLE [API].[FactWeeklyStoreDeptSales] CHECK CONSTRAINT [FK_FactWeeklyStoreDeptSales_DimDepartment_dept_id];
GO

ALTER TABLE [API].[FactWeeklyStoreDeptSales] WITH CHECK ADD CONSTRAINT [FK_FactWeeklyStoreDeptSales_DimCalendarDay_week_start_date] FOREIGN KEY ([week_start_date])
    REFERENCES [API].[DimCalendarDay] ([day_date]);
GO
ALTER TABLE [API].[FactWeeklyStoreDeptSales] CHECK CONSTRAINT [FK_FactWeeklyStoreDeptSales_DimCalendarDay_week_start_date];
GO

ALTER TABLE [API].[FactDailyFeatures] WITH CHECK ADD CONSTRAINT [FK_FactDailyFeatures_DimStore_store_id] FOREIGN KEY ([store_id])
    REFERENCES [API].[DimStore] ([store_id]);
GO
ALTER TABLE [API].[FactDailyFeatures] CHECK CONSTRAINT [FK_FactDailyFeatures_DimStore_store_id];
GO

ALTER TABLE [API].[FactDailyFeatures] WITH CHECK ADD CONSTRAINT [FK_FactDailyFeatures_DimDepartment_dept_id] FOREIGN KEY ([dept_id])
    REFERENCES [API].[DimDepartment] ([dept_id]);
GO
ALTER TABLE [API].[FactDailyFeatures] CHECK CONSTRAINT [FK_FactDailyFeatures_DimDepartment_dept_id];
GO

ALTER TABLE [API].[FactDailyFeatures] WITH CHECK ADD CONSTRAINT [FK_FactDailyFeatures_DimCalendarDay_day_date] FOREIGN KEY ([day_date])
    REFERENCES [API].[DimCalendarDay] ([day_date]);
GO
ALTER TABLE [API].[FactDailyFeatures] CHECK CONSTRAINT [FK_FactDailyFeatures_DimCalendarDay_day_date];
GO

ALTER TABLE [API].[FactDailyTargetAudit] WITH CHECK ADD CONSTRAINT [FK_FactDailyTargetAudit_FactDailyFeatures_store_id_dept_id_day_date] FOREIGN KEY ([store_id], [dept_id], [day_date])
    REFERENCES [API].[FactDailyFeatures] ([store_id], [dept_id], [day_date]);
GO
ALTER TABLE [API].[FactDailyTargetAudit] CHECK CONSTRAINT [FK_FactDailyTargetAudit_FactDailyFeatures_store_id_dept_id_day_date];
GO

ALTER TABLE [API].[FactDailyTrainingLaborOutput] WITH CHECK ADD CONSTRAINT [FK_FactDailyTrainingLaborOutput_FactDailyTargetAudit_store_id_dept_id_day_date] FOREIGN KEY ([store_id], [dept_id], [day_date])
    REFERENCES [API].[FactDailyTargetAudit] ([store_id], [dept_id], [day_date]);
GO
ALTER TABLE [API].[FactDailyTrainingLaborOutput] CHECK CONSTRAINT [FK_FactDailyTrainingLaborOutput_FactDailyTargetAudit_store_id_dept_id_day_date];
GO

ALTER TABLE [API].[FactDailyTrainingLaborOutput] WITH CHECK ADD CONSTRAINT [FK_FactDailyTrainingLaborOutput_LaborBandRule_recommended_labor_band_code] FOREIGN KEY ([recommended_labor_band_code])
    REFERENCES [API].[LaborBandRule] ([recommended_labor_band_code]);
GO
ALTER TABLE [API].[FactDailyTrainingLaborOutput] CHECK CONSTRAINT [FK_FactDailyTrainingLaborOutput_LaborBandRule_recommended_labor_band_code];
GO

ALTER TABLE [src].[FactDailyPrediction] WITH CHECK ADD CONSTRAINT [FK_FactDailyPrediction_ModelRun_model_run_id] FOREIGN KEY ([model_run_id])
    REFERENCES [model].[ModelRun] ([model_run_id]);
GO
ALTER TABLE [src].[FactDailyPrediction] CHECK CONSTRAINT [FK_FactDailyPrediction_ModelRun_model_run_id];
GO

ALTER TABLE [src].[FactDailyPrediction] WITH CHECK ADD CONSTRAINT [FK_FactDailyPrediction_FactDailyFeatures_store_id_dept_id_day_date] FOREIGN KEY ([store_id], [dept_id], [day_date])
    REFERENCES [API].[FactDailyFeatures] ([store_id], [dept_id], [day_date]);
GO
ALTER TABLE [src].[FactDailyPrediction] CHECK CONSTRAINT [FK_FactDailyPrediction_FactDailyFeatures_store_id_dept_id_day_date];
GO

ALTER TABLE [src].[FactDailyPrediction] WITH CHECK ADD CONSTRAINT [FK_FactDailyPrediction_LaborBandRule_predicted_recommended_labor_band_code] FOREIGN KEY ([predicted_recommended_labor_band_code])
    REFERENCES [API].[LaborBandRule] ([recommended_labor_band_code]);
GO
ALTER TABLE [src].[FactDailyPrediction] CHECK CONSTRAINT [FK_FactDailyPrediction_LaborBandRule_predicted_recommended_labor_band_code];
GO

/* Helpful nonclustered indexes for common joins and view filters. */
CREATE INDEX [IX_FactDailyFeatures_DatasetPartition] ON [API].[FactDailyFeatures] ([dataset_partition]);
GO

CREATE INDEX [IX_FactDailyFeatures_DeptId] ON [API].[FactDailyFeatures] ([dept_id]);
GO

CREATE INDEX [IX_FactDailyFeatures_DayDate] ON [API].[FactDailyFeatures] ([day_date]);
GO

CREATE INDEX [IX_FactDailyPrediction_DayDate] ON [src].[FactDailyPrediction] ([day_date]);
GO

CREATE INDEX [IX_FactDailyPrediction_DeptId] ON [src].[FactDailyPrediction] ([dept_id]);
GO

CREATE INDEX [IX_FactDailyTargetAudit_DayDate] ON [API].[FactDailyTargetAudit] ([day_date]);
GO

CREATE INDEX [IX_FactDailyTrainingLaborOutput_LaborBandCode] ON [API].[FactDailyTrainingLaborOutput] ([recommended_labor_band_code]);
GO

CREATE INDEX [IX_FactDailyPrediction_LaborBandCode] ON [src].[FactDailyPrediction] ([predicted_recommended_labor_band_code]);
GO

/* Create views from the Views sheet. */
CREATE VIEW [API].[v_ebm_test_features_model_only]
AS
SELECT
    f.[store_id] AS [store],
    f.[dept_id] AS [dept],
    d.[department_group] AS [poc_department_group],
    s.[store_type] AS [type],
    s.[store_size] AS [size],
    s.[store_size_category] AS [store_size_category],
    f.[temperature] AS [temperature],
    c.[is_holiday] AS [is_holiday],
    c.[day_of_week] AS [day_of_week],
    h.[holiday_name] AS [holiday_name],
    h.[holiday_type] AS [holiday_type],
    h.[related_holiday_name] AS [related_holiday_name],
    h.[related_holiday_type] AS [related_holiday_type],
    h.[holiday_window_role] AS [holiday_window_role],
    h.[days_to_related_holiday] AS [days_to_related_holiday],
    h.[days_since_related_holiday] AS [days_since_related_holiday],
    h.[holiday_grocery_intensity] AS [holiday_grocery_intensity],
    h.[holiday_gift_intensity] AS [holiday_gift_intensity],
    h.[holiday_cookout_intensity] AS [holiday_cookout_intensity],
    h.[holiday_stockup_window_length] AS [holiday_stockup_window_length],
    h.[holiday_day_of_week] AS [holiday_day_of_week],
    h.[is_black_friday_period] AS [is_black_friday_period],
    h.[is_december_holiday_season] AS [is_december_holiday_season],
    d.[holiday_department_profile] AS [holiday_department_profile],
    f.[department_holiday_impact_factor] AS [department_holiday_impact_factor],
    h.[is_costco_closed] AS [is_costco_closed],
    h.[days_to_next_costco_closure] AS [days_to_next_costco_closure],
    h.[days_since_last_costco_closure] AS [days_since_last_costco_closure],
    h.[is_pre_holiday_stockup] AS [is_pre_holiday_stockup],
    h.[is_post_holiday_rebound] AS [is_post_holiday_rebound],
    c.[is_weekend] AS [is_weekend],
    c.[month] AS [month],
    c.[quarter] AS [quarter],
    c.[week_of_year] AS [week_of_year],
    f.[promotion_index] AS [promotion_index],
    f.[has_promotion] AS [has_promotion],
    f.[temperature_category] AS [temperature_category]
FROM [API].[FactDailyFeatures] AS f
INNER JOIN [API].[DimStore] AS s ON s.[store_id] = f.[store_id]
INNER JOIN [API].[DimDepartment] AS d ON d.[dept_id] = f.[dept_id]
INNER JOIN [API].[DimCalendarDay] AS c ON c.[day_date] = f.[day_date]
LEFT JOIN [API].[DimHolidayDay] AS h ON h.[day_date] = f.[day_date]
WHERE LOWER(f.[dataset_partition]) = N'test';
GO

CREATE VIEW [API].[v_ebm_train_features_model_only]
AS
SELECT
    f.[store_id] AS [store],
    f.[dept_id] AS [dept],
    d.[department_group] AS [poc_department_group],
    s.[store_type] AS [type],
    s.[store_size] AS [size],
    s.[store_size_category] AS [store_size_category],
    f.[temperature] AS [temperature],
    c.[is_holiday] AS [is_holiday],
    c.[day_of_week] AS [day_of_week],
    h.[holiday_name] AS [holiday_name],
    h.[holiday_type] AS [holiday_type],
    h.[related_holiday_name] AS [related_holiday_name],
    h.[related_holiday_type] AS [related_holiday_type],
    h.[holiday_window_role] AS [holiday_window_role],
    h.[days_to_related_holiday] AS [days_to_related_holiday],
    h.[days_since_related_holiday] AS [days_since_related_holiday],
    h.[holiday_grocery_intensity] AS [holiday_grocery_intensity],
    h.[holiday_gift_intensity] AS [holiday_gift_intensity],
    h.[holiday_cookout_intensity] AS [holiday_cookout_intensity],
    h.[holiday_stockup_window_length] AS [holiday_stockup_window_length],
    h.[holiday_day_of_week] AS [holiday_day_of_week],
    h.[is_black_friday_period] AS [is_black_friday_period],
    h.[is_december_holiday_season] AS [is_december_holiday_season],
    d.[holiday_department_profile] AS [holiday_department_profile],
    f.[department_holiday_impact_factor] AS [department_holiday_impact_factor],
    h.[is_costco_closed] AS [is_costco_closed],
    h.[days_to_next_costco_closure] AS [days_to_next_costco_closure],
    h.[days_since_last_costco_closure] AS [days_since_last_costco_closure],
    h.[is_pre_holiday_stockup] AS [is_pre_holiday_stockup],
    h.[is_post_holiday_rebound] AS [is_post_holiday_rebound],
    c.[is_weekend] AS [is_weekend],
    c.[month] AS [month],
    c.[quarter] AS [quarter],
    c.[week_of_year] AS [week_of_year],
    f.[promotion_index] AS [promotion_index],
    f.[has_promotion] AS [has_promotion],
    f.[temperature_category] AS [temperature_category],
    t.[busyness_proxy] AS [busyness_proxy]
FROM [API].[FactDailyFeatures] AS f
INNER JOIN [API].[DimStore] AS s ON s.[store_id] = f.[store_id]
INNER JOIN [API].[DimDepartment] AS d ON d.[dept_id] = f.[dept_id]
INNER JOIN [API].[DimCalendarDay] AS c ON c.[day_date] = f.[day_date]
LEFT JOIN [API].[DimHolidayDay] AS h ON h.[day_date] = f.[day_date]
INNER JOIN [API].[FactDailyTargetAudit] AS t ON t.[store_id] = f.[store_id] AND t.[dept_id] = f.[dept_id] AND t.[day_date] = f.[day_date]
WHERE LOWER(f.[dataset_partition]) = N'train';
GO

CREATE VIEW [API].[v_final_predictions_output]
AS
SELECT
    p.[model_run_id] AS [model_run_id],
    p.[store_id] AS [store],
    p.[dept_id] AS [dept],
    d.[department_group] AS [poc_department_group],
    s.[store_size_category] AS [store_size_category],
    c.[week_start_date] AS [week_start_date],
    c.[day_date] AS [day_date],
    c.[day_name] AS [day_name],
    p.[predicted_busyness_proxy] AS [predicted_busyness_proxy],
    p.[predicted_transaction_count_proxy] AS [predicted_transaction_count_proxy],
    p.[predicted_traffic_index] AS [predicted_traffic_index],
    p.[predicted_busyness_band] AS [predicted_busyness_band],
    p.[predicted_labor_planning_context] AS [predicted_labor_planning_context],
    p.[predicted_recommended_labor_band] AS [predicted_recommended_labor_band],
    p.[predicted_recommended_labor_band_code] AS [predicted_recommended_labor_band_code],
    p.[predicted_labor_rule_reason] AS [predicted_labor_rule_reason]
FROM [src].[FactDailyPrediction] AS p
INNER JOIN [API].[DimStore] AS s ON s.[store_id] = p.[store_id]
INNER JOIN [API].[DimDepartment] AS d ON d.[dept_id] = p.[dept_id]
INNER JOIN [API].[DimCalendarDay] AS c ON c.[day_date] = p.[day_date];
GO

PRINT 'LaunchProject schema build complete.';

SELECT s.name AS schema_name, t.name AS table_name FROM sys.tables t INNER JOIN sys.schemas s ON s.schema_id = t.schema_id ORDER BY s.name, t.name;

SELECT s.name AS schema_name, v.name AS view_name FROM sys.views v INNER JOIN sys.schemas s ON s.schema_id = v.schema_id ORDER BY s.name, v.name;
GO

/* ============================================================================
   Section: ModelFeatureRegistry table
============================================================================ */
PRINT '===== Building ModelFeatureRegistry =====';
GO

/*
    LaunchProject - ModelFeatureRegistry table
    Purpose:
      Create [model].[ModelFeatureRegistry] using the columns from the
      costco_oop_normalized_data_dictionary.xlsx / FeatureRegistry sheet.

    Safe to run after LaunchProject schema creation.
    WARNING: This drops and recreates [model].[ModelFeatureRegistry], so existing
    rows in that table will be removed.
*/

USE [LaunchProject];
GO

IF SCHEMA_ID(N'model') IS NULL
BEGIN
    EXEC(N'CREATE SCHEMA [model];');
END;
GO

IF OBJECT_ID(N'[model].[ModelFeatureRegistry]', N'U') IS NOT NULL
BEGIN
    DROP TABLE [model].[ModelFeatureRegistry];
END;
GO

CREATE TABLE [model].[ModelFeatureRegistry] (
    [column_name] NVARCHAR(255) NOT NULL,
    [variable_group] NVARCHAR(255) NULL,
    [poc_role] NVARCHAR(255) NULL,
    [data_type] NVARCHAR(255) NULL,
    [business_meaning] NVARCHAR(MAX) NULL,
    [source_or_derivation] NVARCHAR(MAX) NULL,
    [use_in_ebm_busyness_model] NVARCHAR(255) NULL,
    [ebm_model_treatment] NVARCHAR(MAX) NULL,
    [use_in_post_model_labor_rules] NVARCHAR(255) NULL,
    [business_rule_use] NVARCHAR(MAX) NULL,
    [leakage_risk] NVARCHAR(MAX) NULL,
    [in_full_train_audit_file] BIT NULL,
    [in_full_test_scoring_features_file] BIT NULL,
    [in_ebm_train_model_only_file] BIT NULL,
    [in_ebm_test_model_only_file] BIT NULL,
    [expected_final_output_field] BIT NULL,
    [train_profile] NVARCHAR(MAX) NULL,
    [test_profile] NVARCHAR(MAX) NULL,
    [missing_or_none_handling] NVARCHAR(MAX) NULL,
    [recommended_preprocessing] NVARCHAR(MAX) NULL,
    [notes] NVARCHAR(MAX) NULL,
    [loaded_at] DATETIME2(7) NOT NULL CONSTRAINT [DF_ModelFeatureRegistry_loaded_at] DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT [PK_ModelFeatureRegistry] PRIMARY KEY CLUSTERED ([column_name])
);
GO

/* Optional: load starter/mock registry rows. */
INSERT INTO [model].[ModelFeatureRegistry] (
    [column_name],
    [variable_group],
    [poc_role],
    [data_type],
    [business_meaning],
    [source_or_derivation],
    [use_in_ebm_busyness_model],
    [ebm_model_treatment],
    [use_in_post_model_labor_rules],
    [business_rule_use],
    [leakage_risk],
    [in_full_train_audit_file],
    [in_full_test_scoring_features_file],
    [in_ebm_train_model_only_file],
    [in_ebm_test_model_only_file],
    [expected_final_output_field],
    [train_profile],
    [test_profile],
    [missing_or_none_handling],
    [recommended_preprocessing],
    [notes]
)
VALUES
    (N'store_id', N'Store', N'Model input / join key', N'SMALLINT', N'Store identifier used to learn persistent store-level demand differences.', N'[API].[FactDailyFeatures].[store_id]', N'Yes', N'Treat as categorical; do not ordinally scale.', N'No', N'Used for joins, model scoring grain, and store-level grouping.', N'Low', 1, 1, 1, 1, 0, N'Present for all train rows.', N'Present for all scoring rows.', N'Required / not nullable.', N'Cast to string/category for EBM.', N'Mock starter row aligned to FeatureRegistry sheet.'),
    (N'dept_id', N'Department', N'Model input / join key', N'SMALLINT', N'Department identifier used to learn department-level demand differences.', N'[API].[FactDailyFeatures].[dept_id]', N'Yes', N'Treat as categorical; do not ordinally scale.', N'No', N'Used for joins, model scoring grain, and department-level grouping.', N'Low', 1, 1, 1, 1, 0, N'Present for all train rows.', N'Present for all scoring rows.', N'Required / not nullable.', N'Cast to string/category for EBM.', N'Mock starter row aligned to FeatureRegistry sheet.'),
    (N'day_date', N'Calendar', N'Audit / join key', N'DATE', N'Daily row date used for joins, scoring outputs, and charting.', N'[API].[FactDailyFeatures].[day_date]', N'No', N'Exclude raw date to prevent date memorization.', N'Yes', N'Used for joins to calendar and holiday features.', N'Medium if used directly as model input.', 1, 1, 0, 0, 1, N'Present for all train rows.', N'Present for all scoring rows.', N'Required / not nullable.', N'Join to derived calendar fields instead of feeding raw date.', N'Mock starter row aligned to FeatureRegistry sheet.'),
    (N'day_of_week', N'Calendar', N'Model input', N'SMALLINT', N'Day-of-week signal for weekly demand patterns.', N'[API].[DimCalendarDay].[day_of_week]', N'Yes', N'Use as categorical or cyclic calendar feature.', N'No', N'Calendar demand signal.', N'Low', 1, 1, 1, 1, 0, N'Values 1 through 7.', N'Values 1 through 7.', N'Default unavailable values to unknown only if source issue occurs.', N'Categorical or cyclic encoding.', N'Mock starter row aligned to FeatureRegistry sheet.'),
    (N'is_weekend', N'Calendar', N'Model input', N'BOOLEAN', N'Weekend flag for demand/labor seasonality.', N'[API].[DimCalendarDay].[is_weekend]', N'Yes', N'Binary feature.', N'No', N'Calendar demand signal.', N'Low', 1, 1, 1, 1, 0, N'0/1.', N'0/1.', N'Default to 0 only if derived date logic fails.', N'Use as binary.', N'Mock starter row aligned to FeatureRegistry sheet.'),
    (N'is_holiday', N'Holiday', N'Model input', N'BOOLEAN', N'Holiday flag for demand/labor lift.', N'[API].[DimCalendarDay].[is_holiday]', N'Yes', N'Binary feature.', N'No', N'Holiday demand signal.', N'Low', 1, 1, 1, 1, 0, N'0/1.', N'0/1.', N'Default to 0 when no holiday record exists.', N'Use as binary.', N'Mock starter row aligned to FeatureRegistry sheet.'),
    (N'holiday_window_role', N'Holiday', N'Model input', N'TEXT', N'Pre/post/holiday role around a related holiday.', N'[API].[DimHolidayDay].[holiday_window_role]', N'Yes', N'Categorical feature.', N'Yes', N'Used to explain pre-holiday stock-up and post-holiday rebound.', N'Low', 1, 1, 1, 1, 0, N'pre, holiday, post, normal.', N'pre, holiday, post, normal.', N'Default to normal if no related holiday exists.', N'Categorical encoding.', N'Mock starter row aligned to FeatureRegistry sheet.'),
    (N'holiday_grocery_intensity', N'Holiday', N'Model input', N'NUMERIC', N'Holiday-driven grocery demand intensity.', N'[API].[DimHolidayDay].[holiday_grocery_intensity]', N'Yes', N'Continuous feature.', N'No', N'Holiday demand signal.', N'Low', 1, 1, 1, 1, 0, N'Expected 0 to 1.', N'Expected 0 to 1.', N'Default to 0 when no holiday applies.', N'Keep numeric; validate range.', N'Mock starter row aligned to FeatureRegistry sheet.'),
    (N'holiday_gift_intensity', N'Holiday', N'Model input', N'NUMERIC', N'Holiday-driven gifting/seasonal demand intensity.', N'[API].[DimHolidayDay].[holiday_gift_intensity]', N'Yes', N'Continuous feature.', N'No', N'Holiday demand signal.', N'Low', 1, 1, 1, 1, 0, N'Expected 0 to 1.', N'Expected 0 to 1.', N'Default to 0 when no holiday applies.', N'Keep numeric; validate range.', N'Mock starter row aligned to FeatureRegistry sheet.'),
    (N'holiday_cookout_intensity', N'Holiday', N'Model input', N'NUMERIC', N'Holiday-driven cookout/meal demand intensity.', N'[API].[DimHolidayDay].[holiday_cookout_intensity]', N'Yes', N'Continuous feature.', N'No', N'Holiday demand signal.', N'Low', 1, 1, 1, 1, 0, N'Expected 0 to 1.', N'Expected 0 to 1.', N'Default to 0 when no holiday applies.', N'Keep numeric; validate range.', N'Mock starter row aligned to FeatureRegistry sheet.'),
    (N'temperature', N'Weather', N'Model input / audit field', N'NUMERIC', N'Daily temperature proxy for weather-sensitive demand.', N'[API].[FactDailyFeatures].[temperature]', N'Yes', N'Continuous feature.', N'No', N'Demand signal.', N'Low', 1, 1, 1, 1, 0, N'Expected realistic local weather range.', N'Expected realistic local weather range.', N'Use median imputation if missing.', N'Keep numeric; optional binning with temperature_category.', N'Mock starter row aligned to FeatureRegistry sheet.'),
    (N'temperature_category', N'Weather', N'Model input / audit field', N'TEXT', N'Bucketed weather category derived from temperature.', N'[API].[FactDailyFeatures].[temperature_category]', N'Yes', N'Categorical feature.', N'No', N'Demand signal and interpretability field.', N'Low', 1, 1, 1, 1, 0, N'Cold/Cool/Mild/Warm/Hot.', N'Cold/Cool/Mild/Warm/Hot.', N'Derive from temperature; use Unknown if temperature missing.', N'Categorical encoding.', N'Mock starter row aligned to FeatureRegistry sheet.'),
    (N'promotion_index', N'Promotion', N'Model input', N'NUMERIC', N'Aggregated markdown/promotion signal.', N'[API].[FactDailyFeatures].[promotion_index]', N'Yes', N'Continuous feature.', N'No', N'Demand lift signal.', N'Low', 1, 1, 1, 1, 0, N'Expected non-negative numeric values.', N'Expected non-negative numeric values.', N'Default to 0 when no promotion exists.', N'Keep numeric; consider winsorizing outliers.', N'Mock starter row aligned to FeatureRegistry sheet.'),
    (N'has_promotion', N'Promotion', N'Model input', N'BOOLEAN', N'Flag indicating whether promotion_index is positive.', N'[API].[FactDailyFeatures].[has_promotion]', N'Yes', N'Binary feature.', N'No', N'Demand lift signal.', N'Low', 1, 1, 1, 1, 0, N'0/1.', N'0/1.', N'Default to 0 when promotion_index is null or zero.', N'Use as binary.', N'Mock starter row aligned to FeatureRegistry sheet.'),
    (N'department_holiday_impact_factor', N'Department/Holiday', N'Model input / rule input', N'NUMERIC', N'Department-specific modifier for holiday demand impacts.', N'[API].[FactDailyFeatures].[department_holiday_impact_factor]', N'Yes', N'Continuous feature.', N'Yes', N'Used in holiday demand and labor planning rules.', N'Medium synthetic-rule feature.', 1, 1, 1, 1, 0, N'Expected non-null for training rows.', N'Expected non-null for scoring rows.', N'Default by department group if missing.', N'Keep numeric; document derivation.', N'Mock starter row aligned to FeatureRegistry sheet.'),
    (N'average_ticket_proxy', N'Post Model Rules', N'Rule input', N'NUMERIC', N'Synthetic average ticket assumption used to convert sales/busyness into transaction traffic.', N'[API].[FactDailyFeatures].[average_ticket_proxy]', N'No', N'Do not feed into EBM; use after model output.', N'Yes', N'Post-model traffic and labor calculation input.', N'Medium synthetic-rule feature.', 1, 1, 0, 0, 0, N'Present in full audit rows.', N'Present in full scoring rows.', N'Must be positive when used.', N'Use after prediction only.', N'Mock starter row aligned to FeatureRegistry sheet.'),
    (N'busyness_proxy', N'Target', N'Training target', N'NUMERIC', N'Training target derived from sales and operating assumptions.', N'[API].[FactDailyTargetAudit].[busyness_proxy]', N'No', N'Never include in scoring features.', N'No', N'Model label / evaluation target.', N'High if included in test/scoring feature inputs.', 1, 0, 0, 0, 0, N'Training/evaluation rows only.', N'Excluded from scoring features.', N'Not applicable for scoring inputs.', N'Target only; keep out of feature matrix.', N'Mock starter row aligned to FeatureRegistry sheet.'),
    (N'predicted_busyness_score', N'Model Output', N'Prediction output', N'NUMERIC', N'Predicted daily busyness score output by the model.', N'[src].[FactDailyPrediction].[predicted_busyness_score]', N'No', N'Model output, not an input.', N'Yes', N'Feeds recommended labor calculations.', N'High if accidentally used as training input.', 0, 1, 0, 0, 1, N'Not in train features.', N'Produced by scoring pipeline.', N'Not applicable before scoring.', N'Output only.', N'Mock starter row aligned to FeatureRegistry sheet.'),
    (N'predicted_transactions', N'Model Output', N'Prediction output / rule input', N'NUMERIC', N'Predicted transaction traffic derived from model output and business logic.', N'[src].[FactDailyPrediction].[predicted_transactions]', N'No', N'Model/rule output, not an input.', N'Yes', N'Feeds traffic threshold and labor recommendation logic.', N'High if accidentally used as training input.', 0, 1, 0, 0, 1, N'Not in train features.', N'Produced by scoring pipeline.', N'Not applicable before scoring.', N'Output only.', N'Mock starter row aligned to FeatureRegistry sheet.'),
    (N'recommended_labor_band', N'Model Output', N'Final operational output', N'TEXT', N'Human-readable labor band recommended by the post-model rule layer.', N'[src].[FactDailyPrediction].[recommended_labor_band]', N'No', N'Final output, not an input.', N'Yes', N'Application-facing staffing recommendation.', N'High if used as training input.', 0, 1, 0, 0, 1, N'Not in train features.', N'Produced by scoring/rule pipeline.', N'Not applicable before scoring.', N'Output only.', N'Mock starter row aligned to FeatureRegistry sheet.');
GO

SELECT
    [column_name],
    [variable_group],
    [poc_role],
    [data_type],
    [use_in_ebm_busyness_model],
    [use_in_post_model_labor_rules],
    [expected_final_output_field]
FROM [model].[ModelFeatureRegistry]
ORDER BY [column_name];
GO

/* ============================================================================
   Section: Employee and Notification keys
============================================================================ */
PRINT '===== Adding Employee and Notification keys =====';
GO

/*
    LaunchProject - Employee / Notification keys
    Purpose:
      - Add a Primary Key to [API].[Employee].[ID]
      - Add [src].[Notification].[EmployeeId]
      - Add a Primary Key to [src].[Notification]
      - Add a Foreign Key from [src].[Notification].[EmployeeId] to [API].[Employee].[ID]

    Runs after the table creation sections above.

    Notes:
      - [Employee].[DepartmentIds] and [Employee].[storeIds] are JSON-array columns in the current design.
        SQL Server cannot enforce normal foreign keys inside JSON arrays without redesigning those into bridge tables.
      - [Notification].[EmployeeId] is added as NULLable so the script can be safely run even if existing
        notification rows are present. Any non-null value must match [API].[Employee].[ID].
*/

SET NOCOUNT ON;
GO

USE [LaunchProject];
GO

IF SCHEMA_ID(N'API') IS NULL
BEGIN
    EXEC(N'CREATE SCHEMA [API];');
END;
GO

IF SCHEMA_ID(N'src') IS NULL
BEGIN
    EXEC(N'CREATE SCHEMA [src];');
END;
GO

/* -------------------------------------------------------------------------
   Safety checks: confirm required tables exist.
------------------------------------------------------------------------- */
IF OBJECT_ID(N'[API].[Employee]', N'U') IS NULL
BEGIN
    THROW 51000, 'Required table [API].[Employee] does not exist. Run the main schema script first.', 1;
END;
GO

IF OBJECT_ID(N'[src].[Notification]', N'U') IS NULL
BEGIN
    THROW 51001, 'Required table [src].[Notification] does not exist. Run the main schema script first.', 1;
END;
GO

/* -------------------------------------------------------------------------
   Employee primary key
------------------------------------------------------------------------- */
IF EXISTS (
    SELECT 1
    FROM [API].[Employee]
    GROUP BY [ID]
    HAVING COUNT(*) > 1
)
BEGIN
    THROW 51002, 'Cannot add PK_Employee because duplicate Employee.ID values exist.', 1;
END;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.key_constraints kc
    WHERE kc.parent_object_id = OBJECT_ID(N'[API].[Employee]')
      AND kc.[type] = 'PK'
)
BEGIN
    ALTER TABLE [API].[Employee]
        ADD CONSTRAINT [PK_Employee] PRIMARY KEY CLUSTERED ([ID]);
END;
GO

/* -------------------------------------------------------------------------
   Notification columns and primary key
------------------------------------------------------------------------- */
IF COL_LENGTH(N'src.Notification', N'NotificationId') IS NULL
BEGIN
    ALTER TABLE [src].[Notification]
        ADD [NotificationId] BIGINT IDENTITY(1,1) NOT NULL;
END;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.key_constraints kc
    WHERE kc.parent_object_id = OBJECT_ID(N'[src].[Notification]')
      AND kc.[type] = 'PK'
)
BEGIN
    ALTER TABLE [src].[Notification]
        ADD CONSTRAINT [PK_Notification] PRIMARY KEY CLUSTERED ([NotificationId]);
END;
GO

IF COL_LENGTH(N'src.Notification', N'EmployeeId') IS NULL
BEGIN
    ALTER TABLE [src].[Notification]
        ADD [EmployeeId] SMALLINT NULL;
END;
GO

/* -------------------------------------------------------------------------
   Notification -> Employee foreign key
------------------------------------------------------------------------- */
IF NOT EXISTS (
    SELECT 1
    FROM sys.foreign_keys fk
    WHERE fk.parent_object_id = OBJECT_ID(N'[src].[Notification]')
      AND fk.name = N'FK_Notification_Employee_EmployeeId'
)
BEGIN
    ALTER TABLE [src].[Notification] WITH CHECK
        ADD CONSTRAINT [FK_Notification_Employee_EmployeeId]
        FOREIGN KEY ([EmployeeId])
        REFERENCES [API].[Employee] ([ID]);

    ALTER TABLE [src].[Notification]
        CHECK CONSTRAINT [FK_Notification_Employee_EmployeeId];
END;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'[src].[Notification]')
      AND name = N'IX_Notification_EmployeeId'
)
BEGIN
    CREATE INDEX [IX_Notification_EmployeeId]
        ON [src].[Notification] ([EmployeeId]);
END;
GO

PRINT 'Employee and Notification keys complete.';
GO

SELECT
    s.name AS schema_name,
    t.name AS table_name,
    kc.name AS primary_key_name
FROM sys.key_constraints kc
INNER JOIN sys.tables t
    ON t.object_id = kc.parent_object_id
INNER JOIN sys.schemas s
    ON s.schema_id = t.schema_id
WHERE kc.[type] = 'PK'
  AND (s.name = N'API' AND t.name = N'Employee'
       OR s.name = N'src' AND t.name = N'Notification')
ORDER BY s.name, t.name;
GO

SELECT
    fk.name AS foreign_key_name,
    OBJECT_SCHEMA_NAME(fk.parent_object_id) AS child_schema,
    OBJECT_NAME(fk.parent_object_id) AS child_table,
    c1.name AS child_column,
    OBJECT_SCHEMA_NAME(fk.referenced_object_id) AS parent_schema,
    OBJECT_NAME(fk.referenced_object_id) AS parent_table,
    c2.name AS parent_column
FROM sys.foreign_keys fk
INNER JOIN sys.foreign_key_columns fkc
    ON fkc.constraint_object_id = fk.object_id
INNER JOIN sys.columns c1
    ON c1.object_id = fkc.parent_object_id
   AND c1.column_id = fkc.parent_column_id
INNER JOIN sys.columns c2
    ON c2.object_id = fkc.referenced_object_id
   AND c2.column_id = fkc.referenced_column_id
WHERE fk.name = N'FK_Notification_Employee_EmployeeId';
GO


PRINT '===== LaunchProject full database build complete =====';
GO
