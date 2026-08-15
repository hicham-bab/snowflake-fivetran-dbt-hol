-- ---------------------------------------------------------------------------
-- vw_fs_data_quality
--
-- A composite data-quality scorecard, one row per data domain.
--
-- This is the model the lab uses to tour dbt Studio and Fusion. It is built
-- from a chain of small CTEs on purpose: each one is short enough to read, and
-- each one can be previewed on its own in dbt Studio without running the whole
-- model. Hover any column to see the type Fusion inferred, and break a ref() to
-- watch the error appear before you run anything.
--
-- The financial services version scores a fourth dimension the other tracks do
-- not have: governance. It counts personal-data columns present in the source
-- and personal-data columns reaching the marts. The second number should be
-- zero, and it is not something you want to find out about from a customer.
--
-- Grain: one row per data_domain.
-- ---------------------------------------------------------------------------

{{ config(materialized='view') }}

with customers as (

    select * from {{ ref('stg_risk_assess_customers') }}

),

risk_profiles as (

    select * from {{ ref('stg_risk_assess_risk_profiles') }}

),

assessments as (

    select * from {{ ref('stg_risk_assess_monthly_assessments') }}

),

loans as (

    select * from {{ ref('stg_loan') }}

),

-- ---- customer dimension checks ---------------------------------------------
customer_checks as (

    select
        'Customer dimension' as data_domain,
        count(*) as total_rows,

        -- completeness
        sum(case when customer_segment is null or trim(customer_segment) = '' then 1 else 0 end)
            + sum(case when income_bracket is null or trim(income_bracket) = '' then 1 else 0 end)
            as completeness_failures,
        2 as completeness_checks,

        -- validity: a credit score outside 300-850 is not a credit score
        sum(case when credit_score < 300 or credit_score > 850 then 1 else 0 end)
            + sum(case when debt_to_income_ratio < 0 or debt_to_income_ratio > 1 then 1 else 0 end)
            + sum(case when annual_income <= 0 then 1 else 0 end)
            as validity_failures,
        3 as validity_checks,

        -- consistency: the banded column should agree with the number it bands
        sum(case
                when credit_score_range like 'Excellent%' and credit_score < 800 then 1
                when credit_score_range like 'Poor%' and credit_score >= 580 then 1
                else 0
            end)
            as consistency_failures,
        1 as consistency_checks

    from customers

),

-- ---- risk relationship checks -----------------------------------------------
risk_profile_checks as (

    select
        'Risk relationships' as data_domain,
        count(*) as total_rows,

        -- completeness: the three text-typed numerics are unknown on roughly
        -- two thirds of rows. That is the single biggest completeness gap in
        -- the track, and it is worth surfacing rather than quietly coalescing.
        sum(case when collateral_quality_score is null then 1 else 0 end)
            + sum(case when liquidity_ratio is null then 1 else 0 end)
            + sum(case when projected_cash_flow_rating is null then 1 else 0 end)
            as completeness_failures,
        3 as completeness_checks,

        -- validity
        sum(case when base_risk_score < 0 or base_risk_score > 1 then 1 else 0 end)
            + sum(case when total_exposure <= 0 then 1 else 0 end)
            + sum(case when repayment_history_score < 1 or repayment_history_score > 10 then 1 else 0 end)
            as validity_failures,
        3 as validity_checks,

        -- consistency: a long relationship with only one product, or a
        -- high-exposure relationship with no collateral assessment
        sum(case when relationship_length_months > 60 and products_held = 1 then 1 else 0 end)
            + sum(case when total_exposure > 1000000 and is_collateral_unassessed then 1 else 0 end)
            as consistency_failures,
        2 as consistency_checks

    from risk_profiles

),

-- ---- monthly assessment checks -----------------------------------------------
assessment_checks as (

    select
        'Monthly assessments' as data_domain,
        count(*) as total_rows,

        -- completeness: the blank first-month change, which is expected and
        -- correct, but still worth counting so nobody is surprised by the NULLs
        sum(case when trim(risk_change_from_previous_raw) = '' then 1 else 0 end)
            + sum(case when risk_level is null or trim(risk_level) = '' then 1 else 0 end)
            as completeness_failures,
        2 as completeness_checks,

        -- validity
        sum(case when current_risk_score < 0 or current_risk_score > 1 then 1 else 0 end)
            + sum(case when fraud_probability < 0 or fraud_probability > 1 then 1 else 0 end)
            + sum(case when approval_confidence < 0 or approval_confidence > 1 then 1 else 0 end)
            as validity_failures,
        3 as validity_checks,

        -- consistency: an anomaly flagged with no anomaly type, or a Deny
        -- recommendation on a Very Low risk score
        sum(case when is_anomaly and anomaly_type = 'None' then 1 else 0 end)
            + sum(case when approval_recommendation = 'Deny' and current_risk_score < 0.20 then 1 else 0 end)
            as consistency_failures,
        2 as consistency_checks

    from assessments

),

-- ---- loan portfolio checks -----------------------------------------------------
loan_checks as (

    select
        'Loan portfolio' as data_domain,
        count(*) as total_rows,

        -- completeness: the columns that needed a try_cast are the ones that
        -- come back NULL when the source said 'NA' or left a blank
        sum(case when public_record_bankruptcies is null then 1 else 0 end)
            + sum(case when revolving_utilisation_pct is null then 1 else 0 end)
            + sum(case when issued_at is null then 1 else 0 end)
            as completeness_failures,
        3 as completeness_checks,

        -- validity
        sum(case when funded_amount <= 0 then 1 else 0 end)
            + sum(case when interest_rate_pct <= 0 or interest_rate_pct > 100 then 1 else 0 end)
            + sum(case when annual_income <= 0 then 1 else 0 end)
            as validity_failures,
        3 as validity_checks,

        -- consistency: charged off but no adverse history recorded, or a
        -- debt-to-income ratio of exactly zero on a funded loan
        sum(case when is_charged_off and coalesce(delinquencies_last_2_years, 0) = 0 and coalesce(public_records, 0) = 0 then 1 else 0 end)
            + sum(case when debt_to_income_ratio = 0 then 1 else 0 end)
            as consistency_failures,
        2 as consistency_checks

    from loans

),

-- ---- combine and score -----------------------------------------------------------
combined as (

    select * from customer_checks
    union all
    select * from risk_profile_checks
    union all
    select * from assessment_checks
    union all
    select * from loan_checks

),

scored as (

    select
        data_domain,
        total_rows,
        completeness_failures,
        validity_failures,
        consistency_failures,

        round(100 - (100.0 * completeness_failures / nullif(total_rows * completeness_checks, 0)), 2) as completeness_score,
        round(100 - (100.0 * validity_failures / nullif(total_rows * validity_checks, 0)), 2) as validity_score,
        round(100 - (100.0 * consistency_failures / nullif(total_rows * consistency_checks, 0)), 2) as consistency_score

    from combined

),

final as (

    select
        data_domain,
        total_rows,
        completeness_score,
        validity_score,
        consistency_score,

        round((completeness_score + validity_score + consistency_score) / 3, 2) as data_quality_score,

        case
            when (completeness_score + validity_score + consistency_score) / 3 >= 95 then 'A'
            when (completeness_score + validity_score + consistency_score) / 3 >= 90 then 'B'
            when (completeness_score + validity_score + consistency_score) / 3 >= 80 then 'C'
            else 'D'
        end as data_quality_grade,

        completeness_failures,
        validity_failures,
        consistency_failures

    from scored

)

select * from final
order by data_quality_score asc
