-- ===========================================================================
-- Energy Semantic Views: reference and verification
--
-- DO NOT MAINTAIN THE DDL HERE.
--
-- The definitions live in the dbt project, as models:
--
--     projects/energy/models/marts/sv_energy_commodity_prices.sql
--     projects/energy/models/marts/sv_energy_equipment_reliability.sql
--
-- Built by `dbt build` using the Snowflake-Labs/dbt_semantic_view package.
-- Those models are the source of truth; editing the objects by hand in
-- Snowflake gets overwritten on the next run.
--
-- WHY TWO OBJECTS AND NOT ONE. Commodity trading and equipment maintenance
-- share no key. Putting them in one Semantic View would hand Cortex Analyst a
-- join it cannot make, and produce confidently wrong answers to any question
-- that crossed the two. One object per subject area is the honest shape.
-- ===========================================================================


-- ---------------------------------------------------------------------------
-- 1. What dbt creates
-- ---------------------------------------------------------------------------
--
-- Object A: <database>.<dbt_target_schema>.SV_ENERGY_COMMODITY_PRICES
--   Logical table: prices <- energy_commodity_price_history
--                  (date x commodity grain, 2000-01-04 to 2022-11-04)
--   Metrics:  average_price, latest_price, highest_price, lowest_price,
--             price_volatility, average_daily_change_pct,
--             largest_daily_gain_pct, largest_daily_loss_pct,
--             trading_day_count
--   Dimensions: price_date, commodity, commodity_code, commodity_group,
--               price_unit
--
-- Object B: <database>.<dbt_target_schema>.SV_ENERGY_EQUIPMENT_RELIABILITY
--   Logical table: maintenance <- energy_maintenance_logs
--                  (750 de-duplicated events, 2024-06-27 to 2026-07-16)
--   Metrics:  total_maintenance_cost, average_maintenance_cost,
--             total_downtime_hours, average_downtime_hours,
--             average_failure_rate, cost_per_downtime_hour, event_count,
--             completion_rate, at_risk_rate, unplanned_work_rate,
--             total_analyst_hours_saved
--   Dimensions: log_date, equipment_id, technician_id, customer_id,
--               maintenance_type, maintenance_status, work_class,
--               downtime_band, source_system
--
-- TWO THINGS TO SAY OUT LOUD WHEN DEMOING THIS.
--
-- The price series ends 2022-11-04. Ask "in 2022", never "this year", or the
-- agent will correctly return nothing and it will look broken.
--
-- Every maintenance number is computed on de-duplicated events. Two source
-- feeds report the identical 750 events. Without the de-duplication upstream,
-- this Semantic View would answer every question with exactly double the truth
-- and Cortex Analyst would have no way to know. A semantic layer is only as
-- trustworthy as the model underneath it.


-- ---------------------------------------------------------------------------
-- 2. Verify dbt built them
-- ---------------------------------------------------------------------------

SHOW SEMANTIC VIEWS IN SCHEMA HOL_SNOWFLAKE_INDUSTRY.<dbt_target_schema>;

DESCRIBE SEMANTIC VIEW HOL_SNOWFLAKE_INDUSTRY.<dbt_target_schema>.SV_ENERGY_COMMODITY_PRICES;
DESCRIBE SEMANTIC VIEW HOL_SNOWFLAKE_INDUSTRY.<dbt_target_schema>.SV_ENERGY_EQUIPMENT_RELIABILITY;


-- ---------------------------------------------------------------------------
-- 3. Query them directly, without an agent
-- ---------------------------------------------------------------------------

-- Natural gas through 2022. Note the explicit year: the data stops in 2022.
SELECT *
FROM SEMANTIC_VIEW(
    HOL_SNOWFLAKE_INDUSTRY.<dbt_target_schema>.SV_ENERGY_COMMODITY_PRICES
    METRICS    prices.average_price, prices.highest_price, prices.lowest_price
    DIMENSIONS prices.commodity
    WHERE      prices.commodity = 'Henry Hub natural gas'
               AND prices.price_date >= '2022-01-01'
);

-- Which maintenance strategy costs most per hour of downtime.
SELECT *
FROM SEMANTIC_VIEW(
    HOL_SNOWFLAKE_INDUSTRY.<dbt_target_schema>.SV_ENERGY_EQUIPMENT_RELIABILITY
    METRICS    maintenance.total_maintenance_cost,
               maintenance.cost_per_downtime_hour,
               maintenance.unplanned_work_rate
    DIMENSIONS maintenance.maintenance_type
)
ORDER BY 2 DESC;


-- ---------------------------------------------------------------------------
-- 4. Grants
--
-- Run AFTER the dbt job. See ../GOTCHAS.md section 8 for the rebuild trap.
-- ---------------------------------------------------------------------------

GRANT USAGE  ON DATABASE HOL_SNOWFLAKE_INDUSTRY TO ROLE HOL_ATTENDEE;
GRANT USAGE  ON SCHEMA   HOL_SNOWFLAKE_INDUSTRY.<dbt_target_schema> TO ROLE HOL_ATTENDEE;

GRANT SELECT ON SEMANTIC VIEW HOL_SNOWFLAKE_INDUSTRY.<dbt_target_schema>.SV_ENERGY_COMMODITY_PRICES      TO ROLE HOL_ATTENDEE;
GRANT SELECT ON SEMANTIC VIEW HOL_SNOWFLAKE_INDUSTRY.<dbt_target_schema>.SV_ENERGY_EQUIPMENT_RELIABILITY TO ROLE HOL_ATTENDEE;

-- The underlying tables, or Cortex Analyst returns nothing rather than erroring.
GRANT SELECT ON TABLE HOL_SNOWFLAKE_INDUSTRY.<dbt_target_schema>.ENERGY_COMMODITY_PRICE_HISTORY TO ROLE HOL_ATTENDEE;
GRANT SELECT ON TABLE HOL_SNOWFLAKE_INDUSTRY.<dbt_target_schema>.ENERGY_MAINTENANCE_LOGS         TO ROLE HOL_ATTENDEE;
