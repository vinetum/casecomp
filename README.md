# Costco Workforce Planning - Case Competition Data
Texas MISA Fall 2026. **All data is simulated for this competition. It is not Costco data and does not represent Costco wages, staffing, schedules or service performance.**

## What is included
| Path | Contents |
|---|---|
| `Costco_Workforce_Case_Student_DataPack.xlsx` | Key views and assumptions in Excel (start here if you are not using SQL) |
| `csv/` | Every shift-level table and view as CSV, plus `DATA_DICTIONARY.csv` and `TEAM_SUBMISSION_TEMPLATE.csv` |
| `sql/` | SQL Server scripts that build the full database, including the daily core tables |
| `docs/ASSUMPTIONS.md` | How the data was generated and the assumptions you may use or challenge |
| `docs/DATA_DICTIONARY.md` | Every shift-level field: type, purpose and value category |

## Coverage
- **Three warehouses** (store_id 1 Medium, 2 Large, 4 Large) x **three departments** (38 Front End, 92 Merchandising/Stocking, 95 Pharmacy) x **three shifts** (Opening, Midday, Evening).
- **History:** Thu 2026-01-01 to Wed 2026-02-11 (six weeks). Includes daily sales, traffic, holiday, weather and promotion features, shift demand, schedules, callouts, availability, labor cost and service outcomes. New Year's Day is closed; the MLK weekend is a holiday window.
- **Planning week:** Thu 2026-02-12 to Wed 2026-02-18 (Valentine's Day Saturday, Presidents' Day Monday). Includes the calendar, weather and promotion features, a naive benchmark forecast, the current draft schedule, availability, cost rates and service targets. **Demand is not provided; forecasting it is part of your task.**
- **Scenarios:** BASE, PEAK (promotion + winter-weather surge) and DISRUPT (illness and crew shortages). See `docs/ASSUMPTIONS.md`.

## Building the database (SQL Server / SSMS)
Run in order: `01_Create_Database.sql`, `02_Load_Core_Data.sql`, `03_Create_Shift_Planning_Schema.sql`, `04_Load_Shift_Planning_Data.sql`. Then run `05_Validation_Checks.sql` (every row should read PASS or INFO). `06_Example_Queries.sql` has starter queries.

The two views most teams will use: `comp.v_ShiftHistory` (one row per historical block) and `comp.v_PlanningWeekGrid` (one row per scenario x planning-week block).

## What to submit
All three scenarios (BASE, PEAK and DISRUPT) are required.

| Deliverable | What it should include |
|---|---|
| **Presentation (12-15 minutes)** | Your diagnosis, forecast, recommendation and how it changes across the three scenarios, including a short live demo of your proof of concept. |
| **Staffing plan** | The completed `csv/TEAM_SUBMISSION_TEMPLATE.csv` (details below). |
| **Proof of concept** | A working tool a warehouse leader could use. It should take a scenario as input and show staffing, labor cost and service risk. |
| **Supporting analysis** | Appendix slides or files showing your forecast method, key assumptions, and cost and service compared with the current draft schedule. |

## Filling in the staffing plan
- Fill in `submitted_employees` for every row: one row per scenario x warehouse x department x date x shift (567 rows). Enter 0 for closed blocks.
- Enter the **total** employees for each block. You do not need to split it into regular, overtime and cross-trained staff.
- Labor cost is calculated the same way for every team. Each block is filled with regular available staff first. Next come cross-trained staff from the partner department (Front End and Merchandising only), limited to people that department is not already using in the same shift. Overtime comes last. Use the rates in `comp.LaborCostAssumption`.
- A block staffed above its capacity (regular + usable cross-trained + overtime) or below its minimum staff is flagged as infeasible.
- Plans are evaluated on service performance first, then labor cost, then feasibility.
