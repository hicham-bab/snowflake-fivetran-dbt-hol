-- ---------------------------------------------------------------------------
-- int_cpg_inventory_health
--
-- Product-grain inventory signals. Turns four raw rates into the risk language
-- a supply planner actually uses: is this product likely to run out, or is
-- capital tied up in it?
--
-- Grain: one row per record_id (one product occurrence).
-- ---------------------------------------------------------------------------

{{ config(materialized='view') }}

with products as (

    select * from {{ ref('stg_cpg_records') }}

),

coverage as (

    select
        record_id,
        product_id,
        product_category,
        product_subcategory,
        order_date,

        -- ---- raw inventory facts -------------------------------------------
        inventory_level,
        demand_forecast,
        inventory_turnover,
        stockout_rate,
        overstock_rate,

        -- ---- pricing context -------------------------------------------------
        product_price,
        price_elasticity,
        is_price_optimized,
        price_optimization_recommendation,

        -- ---- product quality signals -----------------------------------------
        product_rating,
        product_review_count,

        -- ---- derived: how many periods of demand the shelf covers -------------
        round(inventory_level / nullif(demand_forecast, 0), 4) as inventory_coverage_ratio

    from products

),

scored as (

    select
        coverage.*,

        -- ---- derived: stockout risk -------------------------------------------
        -- Planning thresholds. Above 5% of periods out of stock the product is
        -- losing sales often enough to warrant a safety-stock review.
        case
            when stockout_rate >= 0.05 then 'High'
            when stockout_rate >= 0.02 then 'Elevated'
            else 'Low'
        end as stockout_risk_level,

        -- ---- derived: overstock risk -------------------------------------------
        -- Overstock is the mirror problem: capital and shelf space tied up.
        case
            when overstock_rate >= 0.10 then 'High'
            when overstock_rate >= 0.05 then 'Elevated'
            else 'Low'
        end as overstock_risk_level,

        -- ---- derived: single flag for the planner's worklist ---------------------
        case
            when stockout_rate >= 0.05 or overstock_rate >= 0.10 then true
            else false
        end as needs_planner_review

    from coverage

)

select * from scored
