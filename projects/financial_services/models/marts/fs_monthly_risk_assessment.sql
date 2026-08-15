-- ---------------------------------------------------------------------------
-- fs_monthly_risk_assessment
--
-- The time-series mart. One row per relationship per month, 106,128 rows
-- covering 2022-01 to 2024-11, with the conformed dimensions attached so risk
-- can be trended by segment, institution type, region and product.
--
-- This is where "is risk getting worse, and for whom" gets answered.
--
-- Contract enforced (see _financial_services__marts.yml).
--
-- Grain: one row per customer_id, institution_id and assessment_date.
-- ---------------------------------------------------------------------------

{{ config(materialized='table') }}

with monthly as (

    select * from {{ ref('int_fs_monthly_risk_enriched') }}

)

select

    -- ---- keys ---------------------------------------------------------------
    cast(assessment_id as number(38, 0)) as assessment_id,
    cast(customer_id as varchar) as customer_id,
    cast(institution_id as varchar) as institution_id,

    -- ---- time ---------------------------------------------------------------
    cast(assessment_date as date) as assessment_date,
    cast(assessment_month as number(38, 0)) as assessment_month,
    cast(assessment_year as number(38, 0)) as assessment_year,

    -- ---- risk measures ---------------------------------------------------------
    cast(current_risk_score as number(9, 4)) as current_risk_score,
    cast(risk_change_from_previous as number(9, 4)) as risk_change_from_previous,
    cast(fraud_probability as number(9, 4)) as fraud_probability,
    cast(approval_confidence as number(9, 4)) as approval_confidence,

    -- ---- activity measures --------------------------------------------------------
    cast(monthly_transaction_volume as number(18, 2)) as monthly_transaction_volume,
    cast(transaction_count as number(38, 0)) as transaction_count,
    cast(total_exposure as number(18, 2)) as total_exposure,

    -- ---- risk dimensions ------------------------------------------------------------
    cast(risk_level as varchar) as risk_level,
    cast(risk_tier as varchar) as risk_tier,
    cast(anomaly_type as varchar) as anomaly_type,
    cast(approval_recommendation as varchar) as approval_recommendation,
    cast(exposure_band as varchar) as exposure_band,
    cast(relationship_stage as varchar) as relationship_stage,
    cast(product_type as varchar) as product_type,

    -- ---- conformed customer dimensions -------------------------------------------------
    cast(customer_segment as varchar) as customer_segment,
    cast(income_bracket as varchar) as income_bracket,
    cast(credit_score_range as varchar) as credit_score_range,
    cast(education_level as varchar) as education_level,
    cast(employment_sector as varchar) as employment_sector,

    -- ---- conformed institution dimensions ------------------------------------------------
    cast(institution_type as varchar) as institution_type,
    cast(institution_size as varchar) as institution_size,
    cast(region as varchar) as region,
    cast(risk_appetite_band as varchar) as risk_appetite_band,
    cast(regulatory_rating as number(38, 0)) as regulatory_rating,

    -- ---- flags --------------------------------------------------------------------------
    cast(is_anomaly as boolean) as is_anomaly,
    cast(is_denied as boolean) as is_denied,
    cast(is_first_assessment as boolean) as is_first_assessment,
    cast(is_material_deterioration as boolean) as is_material_deterioration

from monthly
