-- ---------------------------------------------------------------------------
-- fs_term_deposit_conversion
--
-- Campaign conversion by occupation and education. The classic marketing
-- propensity question: who actually says yes, and how many calls does it take?
-- Optional stretch material: run it with `dbt build --select tag:stretch`.
--
-- Base rate to keep in mind: 5,289 of 45,211 contacts converted, so 11.7%.
-- Any segment below that is being over-called; any segment well above it is
-- being under-called.
--
-- Grain: one row per job_category and education_level.
-- ---------------------------------------------------------------------------

{{ config(
    materialized='table',
    tags=['stretch']
) }}

with contacts as (

    select * from {{ ref('stg_predict_term_deposit') }}

),

aggregated as (

    select
        job_category,
        education_level,

        count(*) as contact_count,
        sum(case when has_subscribed then 1 else 0 end) as subscription_count,

        -- Averaging age only over the rows where it is known. The staging model
        -- already turned the 999 sentinel into NULL, and avg() ignores NULLs,
        -- so this is correct without any extra work here. That is the payoff
        -- for handling the sentinel at the right layer.
        avg(customer_age) as average_age,
        sum(case when is_age_unknown then 1 else 0 end) as unknown_age_count,

        avg(average_yearly_balance) as average_balance,
        avg(last_contact_duration_seconds) as average_contact_duration_seconds,
        avg(contacts_this_campaign) as average_contacts_this_campaign,

        sum(case when has_housing_loan then 1 else 0 end) as housing_loan_count,
        sum(case when has_personal_loan then 1 else 0 end) as personal_loan_count,
        sum(case when is_first_campaign then 1 else 0 end) as first_campaign_count

    from contacts
    group by
        job_category,
        education_level

)

select

    -- ---- keys ---------------------------------------------------------------
    cast(job_category as varchar) as job_category,
    cast(education_level as varchar) as education_level,

    -- ---- volumes -------------------------------------------------------------
    cast(contact_count as number(38, 0)) as contact_count,
    cast(subscription_count as number(38, 0)) as subscription_count,

    -- ---- the headline metric ---------------------------------------------------
    cast(
        subscription_count / nullif(contact_count, 0)
        as number(9, 6)
    ) as conversion_rate,

    -- ---- effort ----------------------------------------------------------------
    cast(average_contacts_this_campaign as number(9, 4)) as average_contacts_this_campaign,
    cast(average_contact_duration_seconds as number(9, 2)) as average_contact_duration_seconds,

    -- ---- who they are -------------------------------------------------------------
    cast(average_age as number(9, 2)) as average_age,
    cast(unknown_age_count as number(38, 0)) as unknown_age_count,
    cast(average_balance as number(18, 2)) as average_balance,

    -- ---- what they already hold -------------------------------------------------------
    cast(housing_loan_count as number(38, 0)) as housing_loan_count,
    cast(personal_loan_count as number(38, 0)) as personal_loan_count,
    cast(first_campaign_count as number(38, 0)) as first_campaign_count

from aggregated
