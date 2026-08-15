-- ---------------------------------------------------------------------------
-- int_fs_monthly_risk_enriched
--
-- The monthly time series, with the conformed dimensions attached so risk can
-- be tracked over time by customer segment, institution type, region and
-- product.
--
-- This model also makes the one business decision that staging deliberately
-- left alone: what `risk_change_from_previous` means when it is blank. It is
-- blank on the first assessment of every relationship, 2,948 rows, because
-- there is no previous month to compare to. That is "unknown", not "zero", and
-- the two are different: a zero would drag the average change towards nothing,
-- a NULL is correctly ignored by an average.
--
-- Grain: one row per customer_id, institution_id and assessment_date.
-- ---------------------------------------------------------------------------

{{ config(materialized='view') }}

with assessments as (

    select * from {{ ref('stg_risk_assess_monthly_assessments') }}

),

relationships as (

    select * from {{ ref('int_fs_risk_relationships') }}

),

converted as (

    select
        assessments.*,

        -- HOL_BUG_FS_01
        cast(assessments.risk_change_from_previous_raw as number(9, 4)) as risk_change_from_previous,

        -- Whether this is the first assessment of the relationship. Useful in
        -- its own right, and it makes the NULL above explainable to anyone
        -- reading a report.
        case
            when trim(assessments.risk_change_from_previous_raw) = '' then true
            else false
        end as is_first_assessment

    from assessments

),

enriched as (

    select

        -- ---- keys ------------------------------------------------------------
        converted.assessment_id,
        converted.customer_id,
        converted.institution_id,

        -- ---- time --------------------------------------------------------------
        converted.assessment_date,
        converted.assessment_month,
        converted.assessment_year,

        -- ---- monthly risk facts -------------------------------------------------
        converted.current_risk_score,
        converted.risk_level,
        converted.risk_change_from_previous,
        converted.is_first_assessment,
        converted.fraud_probability,
        converted.is_anomaly,
        converted.anomaly_type,

        -- ---- monthly activity ------------------------------------------------------
        converted.monthly_transaction_volume,
        converted.transaction_count,

        -- ---- decisioning -------------------------------------------------------------
        converted.approval_recommendation,
        converted.approval_confidence,

        -- ---- conformed customer dimension ----------------------------------------------
        relationships.customer_segment,
        relationships.income_bracket,
        relationships.credit_score_range,
        relationships.education_level,
        relationships.employment_sector,

        -- ---- conformed institution dimension ---------------------------------------------
        relationships.institution_type,
        relationships.institution_size,
        relationships.region,
        relationships.regulatory_rating,
        relationships.risk_appetite_band,

        -- ---- conformed relationship attributes ---------------------------------------------
        relationships.product_type,
        relationships.risk_tier,
        relationships.exposure_band,
        relationships.relationship_stage,
        relationships.total_exposure,

        -- ---- derived: is this month's decision a rejection ------------------------------------
        case
            when converted.approval_recommendation = 'Deny' then true
            else false
        end as is_denied,

        -- ---- derived: did risk get materially worse this month ----------------------------------
        -- A tenth of a point on a 0-to-1 scale is the threshold the credit
        -- committee treats as worth a look.
        case
            when try_cast(converted.risk_change_from_previous_raw as number(9, 4)) is null then null
            when try_cast(converted.risk_change_from_previous_raw as number(9, 4)) >= 0.10 then true
            else false
        end as is_material_deterioration

    from converted

    inner join relationships
        on converted.customer_id = relationships.customer_id
        and converted.institution_id = relationships.institution_id

)

select * from enriched
