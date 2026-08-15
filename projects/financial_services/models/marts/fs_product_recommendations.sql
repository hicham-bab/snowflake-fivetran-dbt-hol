-- ---------------------------------------------------------------------------
-- fs_product_recommendations
--
-- Product recommendation outcomes by customer segment and lifecycle stage.
-- Optional stretch material: run it with `dbt build --select tag:stretch`.
--
-- Grain: one row per recommendation_id.
-- ---------------------------------------------------------------------------

{{ config(
    materialized='table',
    tags=['stretch']
) }}

with recommendations as (

    select * from {{ ref('stg_fpr_records') }}

)

select

    -- ---- keys ---------------------------------------------------------------
    cast(recommendation_id as varchar) as recommendation_id,
    cast(customer_id as varchar) as customer_id,
    cast(product_id as varchar) as product_id,

    -- HOL_BUG_FS_04
    cast(customer_email as varchar) as customer_email,

    -- ---- time ---------------------------------------------------------------
    cast(recommended_at as date) as recommended_at,
    cast(sold_at as date) as sold_at,

    -- ---- dimensions ----------------------------------------------------------
    cast(product_name as varchar) as product_name,
    cast(product_type as varchar) as product_type,
    cast(recommended_product as varchar) as recommended_product,
    cast(recommendation_status as varchar) as recommendation_status,
    cast(recommendation_outcome as varchar) as recommendation_outcome,
    cast(customer_segment as varchar) as customer_segment,
    cast(customer_lifecycle_stage as varchar) as customer_lifecycle_stage,

    -- ---- measures --------------------------------------------------------------
    cast(recommendation_score as number(9, 6)) as recommendation_score,
    cast(account_balance as number(18, 2)) as account_balance,
    cast(customer_satisfaction_score as number(9, 4)) as customer_satisfaction_score,
    cast(customer_churn_probability as number(9, 6)) as customer_churn_probability,
    cast(customer_transaction_count as number(38, 0)) as customer_transaction_count,
    cast(customer_transaction_value as number(18, 2)) as customer_transaction_value,
    cast(product_sales_amount as number(18, 2)) as product_sales_amount,

    -- ---- flags -----------------------------------------------------------------
    cast(is_accepted as boolean) as is_accepted

from recommendations
