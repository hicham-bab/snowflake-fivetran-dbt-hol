-- ---------------------------------------------------------------------------
-- int_fs_risk_relationships
--
-- The star join. One row per customer and institution relationship, with both
-- conformed dimensions attached and the pre-aggregated performance metrics
-- alongside.
--
-- This is the model that makes the rest of the track possible: everything
-- downstream slices risk by attributes of the customer, attributes of the
-- institution, or both, and this is where those attributes get attached.
--
-- Join integrity, checked rather than assumed: all 2,948 relationships resolve
-- to a customer and to an institution, with zero orphans in either direction.
-- The joins below are inner joins because of that. If the data ever changes and
-- an orphan appears, an inner join silently drops it, which is why
-- tests/assert_no_orphan_risk_relationships.sql exists.
--
-- Grain: one row per customer_id and institution_id.
-- ---------------------------------------------------------------------------

{{ config(materialized='view') }}

with risk_profiles as (

    select * from {{ ref('stg_risk_assess_risk_profiles') }}

),

customers as (

    select * from {{ ref('stg_risk_assess_customers') }}

),

institutions as (

    select * from {{ ref('stg_risk_assess_financial_institutions') }}

),

performance as (

    select * from {{ ref('stg_risk_assess_performance_metrics') }}

),

-- A relationship summary is a snapshot, and a snapshot needs a date. There is
-- no date on the relationship itself, so the honest one is the last date the
-- portfolio was assessed. Reading it from staging rather than from the monthly
-- intermediate keeps the DAG acyclic.
as_of as (

    select max(assessment_date) as as_of_date
    from {{ ref('stg_risk_assess_monthly_assessments') }}

),

joined as (

    select

        -- ---- keys -----------------------------------------------------------
        risk_profiles.risk_profile_id,
        risk_profiles.customer_id,
        risk_profiles.institution_id,

        -- ---- snapshot date -----------------------------------------------------
        as_of.as_of_date,

        -- ---- relationship facts ------------------------------------------------
        risk_profiles.product_type,
        risk_profiles.risk_pattern,
        risk_profiles.base_risk_score,
        risk_profiles.total_exposure,
        risk_profiles.relationship_length_months,
        risk_profiles.products_held,
        risk_profiles.repayment_history_score,
        risk_profiles.collateral_quality_score,
        risk_profiles.liquidity_ratio,
        risk_profiles.projected_cash_flow_rating,
        risk_profiles.is_collateral_unassessed,
        risk_profiles.recent_transaction_volatility,
        risk_profiles.primary_risk_factors,

        -- ---- customer dimension --------------------------------------------------
        customers.customer_segment,
        customers.income_bracket,
        customers.credit_score,
        customers.credit_score_range,
        customers.education_level,
        customers.employment_sector,
        customers.annual_income,
        customers.debt_to_income_ratio,
        customers.years_of_credit_history,
        customers.num_credit_accounts,
        customers.num_delinquencies_last_2_years,
        customers.is_homeowner,
        customers.has_previous_bankruptcy,

        -- ---- institution dimension -------------------------------------------------
        institutions.institution_name,
        institutions.institution_type,
        institutions.institution_size,
        institutions.region,
        institutions.regulatory_rating,
        institutions.risk_appetite_score,
        institutions.risk_appetite_band,
        institutions.primary_risk_model,
        institutions.default_rate_percentage,
        institutions.fraud_loss_percentage,

        -- ---- pre-aggregated performance ----------------------------------------------
        -- Kept under their source names so it stays obvious these are numbers
        -- somebody else calculated, not ones this project derived.
        performance.avg_risk_score,
        performance.risk_score_volatility,
        performance.risk_trend,
        performance.avg_fraud_probability,
        performance.anomaly_percentage,
        performance.approval_percentage,
        performance.risk_adjusted_return,
        performance.customer_value_score,
        performance.customer_value_category,
        performance.total_transaction_volume,
        performance.optimization_priority

    from risk_profiles

    inner join customers
        on risk_profiles.customer_id = customers.customer_id

    inner join institutions
        on risk_profiles.institution_id = institutions.institution_id

    -- Performance metrics are at the same grain, plus product_type. Joining on
    -- all three keys keeps it one-to-one.
    inner join performance
        on risk_profiles.customer_id = performance.customer_id
        and risk_profiles.institution_id = performance.institution_id
        and risk_profiles.product_type = performance.product_type

    -- One row, no join key. A cross join to a single-row CTE is the standard
    -- way to attach a scalar to every row.
    cross join as_of

),

banded as (

    select
        joined.*,

        -- ---- derived: the tier a credit committee actually talks in --------------
        case
            when base_risk_score >= 0.80 then 'Very High'
            when base_risk_score >= 0.60 then 'High'
            when base_risk_score >= 0.40 then 'Moderate'
            when base_risk_score >= 0.20 then 'Low'
            else 'Very Low'
        end as risk_tier,

        -- ---- derived: exposure banding ---------------------------------------------
        case
            when total_exposure >= 1000000 then 'Over 1M'
            when total_exposure >= 100000 then '100K to 1M'
            when total_exposure >= 10000 then '10K to 100K'
            else 'Under 10K'
        end as exposure_band,

        -- ---- derived: tenure ---------------------------------------------------------
        case
            when relationship_length_months >= 60 then 'Established'
            when relationship_length_months >= 24 then 'Developing'
            else 'New'
        end as relationship_stage,

        -- ---- derived: risk-weighted exposure -------------------------------------------
        -- The number a risk officer reaches for first: how much money is at
        -- stake, weighted by how likely it is to go wrong.
        round(total_exposure * base_risk_score, 2) as risk_weighted_exposure

    from joined

)

select * from banded
