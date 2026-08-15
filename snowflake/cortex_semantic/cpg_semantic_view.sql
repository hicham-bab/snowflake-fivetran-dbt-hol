-- ===========================================================================
-- Consumer packaged goods Semantic View: reference and verification
--
-- DO NOT MAINTAIN THE DDL HERE.
--
-- The definition lives in the dbt project, as a model:
--
--     projects/cpg/models/marts/sv_cpg_commercial_performance.sql
--
-- It is built by `dbt build` using the Snowflake-Labs/dbt_semantic_view
-- package, which is a direct passthrough to CREATE SEMANTIC VIEW. That model
-- is the single source of truth: it is versioned in git, reviewed in a pull
-- request, and rebuilt on every production run.
--
-- If you edit the object by hand in Snowflake, the next dbt run overwrites
-- your change without warning. This file exists so the Snowflake team can
-- verify what dbt created, grant access to it, and understand its shape
-- without reading dbt.
-- ===========================================================================


-- ---------------------------------------------------------------------------
-- 1. What dbt creates
-- ---------------------------------------------------------------------------
--
-- Object:  <database>.<dbt_target_schema>.SV_CPG_COMMERCIAL_PERFORMANCE
--
-- Logical tables:
--   orders      <- cpg_order_performance          (750 rows, order-line grain)
--   inventory   <- cpg_product_inventory_health   (750 rows, product grain)
--
-- Relationship:
--   orders (record_id) REFERENCES inventory (record_id)
--
-- Metrics exposed to Cortex Analyst:
--   orders.total_order_value             sum of order value, incl. cancellations
--   orders.total_recognised_revenue      sum excluding cancellations  <- use this for revenue
--   orders.order_count                   count of order lines
--   orders.average_order_value           value / count
--   orders.average_customer_lifetime_value
--   orders.average_product_rating
--   orders.fulfilment_rate               share shipped or delivered
--   orders.cancellation_rate             share cancelled
--   inventory.average_stockout_rate
--   inventory.average_overstock_rate
--   inventory.average_inventory_turnover
--   inventory.total_inventory_units
--   inventory.products_needing_review    high stockout or high overstock risk
--
-- Dimensions:
--   order_date, order_status, customer_segment, product_category,
--   product_subcategory, order_value_band, stockout_risk_level,
--   overstock_risk_level
--
-- Note on revenue: total_order_value and total_recognised_revenue differ by
-- roughly a quarter, because 192 of the 750 order lines are cancelled and
-- still carry a value in the raw feed. Both are exposed on purpose, with
-- comments telling the agent which one means revenue.


-- ---------------------------------------------------------------------------
-- 2. Verify dbt built it
-- ---------------------------------------------------------------------------

SHOW SEMANTIC VIEWS IN SCHEMA HOL_SNOWFLAKE_INDUSTRY.<dbt_target_schema>;

DESCRIBE SEMANTIC VIEW HOL_SNOWFLAKE_INDUSTRY.<dbt_target_schema>.SV_CPG_COMMERCIAL_PERFORMANCE;


-- ---------------------------------------------------------------------------
-- 3. Query it directly, without an agent
--
-- Useful for proving the object works before blaming Cortex Analyst.
-- ---------------------------------------------------------------------------

SELECT *
FROM SEMANTIC_VIEW(
    HOL_SNOWFLAKE_INDUSTRY.<dbt_target_schema>.SV_CPG_COMMERCIAL_PERFORMANCE
    METRICS    orders.total_recognised_revenue, orders.average_order_value
    DIMENSIONS orders.product_category
)
ORDER BY 2 DESC;

SELECT *
FROM SEMANTIC_VIEW(
    HOL_SNOWFLAKE_INDUSTRY.<dbt_target_schema>.SV_CPG_COMMERCIAL_PERFORMANCE
    METRICS    inventory.average_stockout_rate, inventory.products_needing_review
    DIMENSIONS inventory.inventory_product_category
)
ORDER BY 2 DESC;


-- ---------------------------------------------------------------------------
-- 4. Grants
--
-- Run AFTER the dbt job. The object does not exist before it.
--
-- The rebuild trap: by default the package issues CREATE OR REPLACE SEMANTIC
-- VIEW, which drops the object and every grant on it. Either set
-- create_or_alter=true in the dbt model config, or re-run these after each job.
-- Snowflake does not support COPY GRANTS with CREATE OR ALTER, so those two are
-- alternatives rather than a pair. See ../GOTCHAS.md section 8.
-- ---------------------------------------------------------------------------

GRANT USAGE  ON DATABASE HOL_SNOWFLAKE_INDUSTRY TO ROLE HOL_ATTENDEE;
GRANT USAGE  ON SCHEMA   HOL_SNOWFLAKE_INDUSTRY.<dbt_target_schema> TO ROLE HOL_ATTENDEE;
GRANT SELECT ON SEMANTIC VIEW HOL_SNOWFLAKE_INDUSTRY.<dbt_target_schema>.SV_CPG_COMMERCIAL_PERFORMANCE TO ROLE HOL_ATTENDEE;

-- A Semantic View does not launder permissions. The querying role also needs
-- SELECT on the tables underneath it, or Cortex Analyst returns nothing at all
-- rather than an error.
GRANT SELECT ON TABLE HOL_SNOWFLAKE_INDUSTRY.<dbt_target_schema>.CPG_ORDER_PERFORMANCE        TO ROLE HOL_ATTENDEE;
GRANT SELECT ON TABLE HOL_SNOWFLAKE_INDUSTRY.<dbt_target_schema>.CPG_PRODUCT_INVENTORY_HEALTH TO ROLE HOL_ATTENDEE;
