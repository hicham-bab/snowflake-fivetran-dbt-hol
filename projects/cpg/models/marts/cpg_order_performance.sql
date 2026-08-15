-- ---------------------------------------------------------------------------
-- cpg_order_performance
--
-- Business-facing order fact. This is what the commercial team queries and what
-- the semantic layer sits on top of.
--
-- This model has an ENFORCED CONTRACT (see _cpg__marts.yml). That means dbt
-- checks the name, type and count of every column before it writes the table.
-- If the model and the contract disagree, the build fails rather than quietly
-- changing the shape of a table that other people depend on.
--
-- Because the contract is enforced, every column below is cast explicitly. The
-- cast in the SQL and the data_type in the YAML have to agree exactly.
--
-- Grain: one row per record_id (one order line).
-- ---------------------------------------------------------------------------

{{ config(materialized='table') }}

with orders as (

    select * from {{ ref('int_cpg_order_performance') }}

)

select

    -- ---- keys ---------------------------------------------------------------
    cast(record_id as varchar) as record_id,
    cast(order_id as varchar) as order_id,
    cast(customer_id as varchar) as customer_id,
    cast(product_id as varchar) as product_id,

    -- ---- time ---------------------------------------------------------------
    cast(order_date as date) as order_date,

    -- ---- dimensions ----------------------------------------------------------
    cast(order_status as varchar) as order_status,
    cast(customer_segment as varchar) as customer_segment,
    cast(product_category as varchar) as product_category,
    cast(product_subcategory as varchar) as product_subcategory,
    cast(order_value_band as varchar) as order_value_band,

    -- ---- measures --------------------------------------------------------------
    cast(order_total as number(18, 2)) as order_total,
    cast(recognised_revenue as number(18, 2)) as recognised_revenue,
    cast(product_price as number(18, 2)) as product_price,
    cast(implied_units as number(18, 2)) as implied_units,
    cast(customer_lifetime_value as number(18, 2)) as customer_lifetime_value,
    cast(product_rating as number(9, 4)) as product_rating,
    cast(product_review_count as number(38, 0)) as product_review_count,
    cast(revenue_growth_rate as number(9, 6)) as revenue_growth_rate,
    cast(customer_satisfaction_rate as number(9, 6)) as customer_satisfaction_rate,

    -- ---- flags -----------------------------------------------------------------
    cast(is_fulfilled_order as boolean) as is_fulfilled_order,
    cast(is_cancelled_order as boolean) as is_cancelled_order

from orders
