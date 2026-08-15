-- ---------------------------------------------------------------------------
-- fs_loan_portfolio
--
-- Consumer loan portfolio, 39,717 applications, with none of the 12 personal
-- data columns the source carries.
--
-- This mart is the governance proof. Its contract is the list of what is
-- allowed out. If someone adds an SSN column back into stg_loan.sql, this
-- model does not quietly grow a column: the contract fails the build and
-- somebody has to explain themselves in a pull request.
--
-- That is the argument for contracts on anything an AI agent can reach. A
-- semantic view will happily describe whatever columns it finds.
--
-- Contract enforced (see _financial_services__marts.yml).
--
-- Grain: one row per loan_id.
-- ---------------------------------------------------------------------------

{{ config(materialized='table') }}

with loans as (

    select * from {{ ref('stg_loan') }}

),

banded as (

    select
        loans.*,

        -- ---- derived: loan size banding -----------------------------------
        case
            when funded_amount >= 25000 then 'Over 25K'
            when funded_amount >= 15000 then '15K to 25K'
            when funded_amount >= 5000 then '5K to 15K'
            else 'Under 5K'
        end as funded_amount_band,

        -- ---- derived: income banding ---------------------------------------
        case
            when annual_income >= 150000 then 'Over 150K'
            when annual_income >= 75000 then '75K to 150K'
            when annual_income >= 40000 then '40K to 75K'
            else 'Under 40K'
        end as income_band,

        -- ---- derived: is the grade investment-like ----------------------------
        -- A and B are where the book is supposed to sit; everything from D down
        -- is priced for a materially higher default rate.
        case
            when credit_grade in ('A', 'B') then 'Prime'
            when credit_grade = 'C' then 'Near-prime'
            else 'Subprime'
        end as grade_tier,

        -- ---- derived: any adverse credit history --------------------------------
        case
            when coalesce(delinquencies_last_2_years, 0) > 0
                or coalesce(public_record_bankruptcies, 0) > 0
                or coalesce(public_records, 0) > 0
            then true
            else false
        end as has_adverse_credit_history

    from loans

)

select

    -- ---- keys ---------------------------------------------------------------
    cast(loan_id as number(38, 0)) as loan_id,

    -- ---- time ---------------------------------------------------------------
    cast(issued_at as date) as issued_at,

    -- ---- loan dimensions -------------------------------------------------------
    cast(credit_grade as varchar) as credit_grade,
    cast(credit_sub_grade as varchar) as credit_sub_grade,
    cast(grade_tier as varchar) as grade_tier,
    cast(loan_purpose as varchar) as loan_purpose,
    cast(loan_status as varchar) as loan_status,
    cast(income_verification_status as varchar) as income_verification_status,
    cast(funded_amount_band as varchar) as funded_amount_band,

    -- ---- borrower dimensions ------------------------------------------------------
    -- state_code is the finest geographic grain in this mart. zip_code exists
    -- in the source and is excluded: three digits of postcode plus state plus
    -- income is a well-documented re-identification path.
    cast(state_code as varchar) as state_code,
    cast(home_ownership as varchar) as home_ownership,
    cast(income_band as varchar) as income_band,

    -- ---- loan measures ---------------------------------------------------------------
    cast(funded_amount as number(18, 2)) as funded_amount,
    cast(term_months as number(38, 0)) as term_months,
    cast(interest_rate_pct as number(9, 4)) as interest_rate_pct,

    -- ---- borrower measures -------------------------------------------------------------
    cast(annual_income as number(18, 2)) as annual_income,
    cast(debt_to_income_ratio as number(9, 4)) as debt_to_income_ratio,
    cast(revolving_utilisation_pct as number(9, 4)) as revolving_utilisation_pct,
    cast(open_accounts as number(38, 0)) as open_accounts,
    cast(total_accounts as number(38, 0)) as total_accounts,
    cast(delinquencies_last_2_years as number(38, 0)) as delinquencies_last_2_years,
    cast(public_records as number(38, 0)) as public_records,
    cast(public_record_bankruptcies as number(38, 0)) as public_record_bankruptcies,

    -- ---- flags -----------------------------------------------------------------------------
    cast(is_charged_off as boolean) as is_charged_off,
    cast(has_adverse_credit_history as boolean) as has_adverse_credit_history

from banded
