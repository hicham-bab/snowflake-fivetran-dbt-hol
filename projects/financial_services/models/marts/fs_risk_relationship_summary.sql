-- ---------------------------------------------------------------------------
-- fs_risk_relationship_summary
--
-- The headline mart of the financial services track. One row per customer and
-- institution relationship, with both conformed dimensions attached, the risk
-- tier, the exposure band and the risk-weighted exposure.
--
-- This is what a credit risk committee would put on the wall: 2,948
-- relationships across 1,000 customers and 20 institutions, sliceable by who
-- the customer is, who the institution is, and what they hold together.
--
-- Contract enforced (see _financial_services__marts.yml), so every column is
-- cast explicitly.
--
-- Grain: one row per customer_id and institution_id.
-- ---------------------------------------------------------------------------

{{ config(materialized='table') }}

with relationships as (

    select * from {{ ref('int_fs_risk_relationships') }}

)

select

    -- ---- keys ---------------------------------------------------------------
    cast(risk_profile_id as number(38, 0)) as risk_profile_id,
    cast(customer_id as varchar) as customer_id,
    cast(institution_id as varchar) as institution_id,

    -- ---- snapshot date ----------------------------------------------------------
    -- The last date the portfolio was assessed. Every row carries the same
    -- value: this is a snapshot, and this is what it is a snapshot of.
    cast(as_of_date as date) as as_of_date,

    -- ---- relationship dimensions ----------------------------------------------
    cast(product_type as varchar) as product_type,
    cast(risk_pattern as varchar) as risk_pattern,
    cast(risk_tier as varchar) as risk_tier,
    cast(exposure_band as varchar) as exposure_band,
    cast(relationship_stage as varchar) as relationship_stage,

    -- ---- customer dimensions -----------------------------------------------------
    cast(customer_segment as varchar) as customer_segment,
    cast(income_bracket as varchar) as income_bracket,
    cast(credit_score_range as varchar) as credit_score_range,
    cast(education_level as varchar) as education_level,
    cast(employment_sector as varchar) as employment_sector,

    -- ---- institution dimensions ----------------------------------------------------
    cast(institution_name as varchar) as institution_name,
    cast(institution_type as varchar) as institution_type,
    cast(institution_size as varchar) as institution_size,
    cast(region as varchar) as region,
    cast(risk_appetite_band as varchar) as risk_appetite_band,
    cast(primary_risk_model as varchar) as primary_risk_model,
    cast(regulatory_rating as number(38, 0)) as regulatory_rating,

    -- ---- risk measures ---------------------------------------------------------------
    cast(base_risk_score as number(9, 4)) as base_risk_score,
    cast(repayment_history_score as number(38, 0)) as repayment_history_score,
    cast(collateral_quality_score as number(9, 4)) as collateral_quality_score,
    cast(liquidity_ratio as number(9, 4)) as liquidity_ratio,
    cast(projected_cash_flow_rating as number(9, 4)) as projected_cash_flow_rating,
    cast(recent_transaction_volatility as number(9, 4)) as recent_transaction_volatility,

    -- ---- exposure measures -------------------------------------------------------------
    cast(total_exposure as number(18, 2)) as total_exposure,
    cast(risk_weighted_exposure as number(18, 2)) as risk_weighted_exposure,
    cast(relationship_length_months as number(38, 0)) as relationship_length_months,
    cast(products_held as number(38, 0)) as products_held,

    -- ---- borrower credit measures --------------------------------------------------------
    cast(credit_score as number(38, 0)) as credit_score,
    cast(annual_income as number(18, 2)) as annual_income,
    cast(debt_to_income_ratio as number(9, 4)) as debt_to_income_ratio,
    cast(years_of_credit_history as number(38, 0)) as years_of_credit_history,
    cast(num_delinquencies_last_2_years as number(38, 0)) as num_delinquencies_last_2_years,

    -- ---- pre-aggregated performance measures ------------------------------------------------
    cast(avg_risk_score as number(9, 4)) as avg_risk_score,
    cast(risk_score_volatility as number(9, 4)) as risk_score_volatility,
    cast(avg_fraud_probability as number(9, 4)) as avg_fraud_probability,
    cast(anomaly_percentage as number(9, 4)) as anomaly_percentage,
    cast(approval_percentage as number(9, 4)) as approval_percentage,
    cast(risk_adjusted_return as number(9, 4)) as risk_adjusted_return,
    cast(customer_value_score as number(38, 0)) as customer_value_score,
    cast(customer_value_category as varchar) as customer_value_category,
    cast(risk_trend as varchar) as risk_trend,
    cast(optimization_priority as varchar) as optimization_priority,

    -- ---- flags -------------------------------------------------------------------------------
    cast(is_homeowner as boolean) as is_homeowner,
    cast(has_previous_bankruptcy as boolean) as has_previous_bankruptcy,
    cast(is_collateral_unassessed as boolean) as is_collateral_unassessed

from relationships
