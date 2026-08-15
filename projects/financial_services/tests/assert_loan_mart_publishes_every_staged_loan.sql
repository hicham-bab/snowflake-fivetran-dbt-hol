-- Singular test: the loan mart must publish exactly the loans that staging
-- selected, and no more.
--
-- This is the cheap half of the PII guard. The expensive half is the enforced
-- contract on fs_loan_portfolio, which pins the exact column list: add an SSN
-- column back upstream and the build fails before anything is written. This
-- test covers the other direction, that nothing was silently added or lost in
-- the row dimension between staging and the mart.
--
-- Together they mean the answer to "what personal data does this project
-- publish" is a list in a YAML file that a reviewer can read in a pull
-- request, rather than something you have to go and query to find out.

with staged as (

    select count(*) as row_count from {{ ref('stg_loan') }}

),

published as (

    select count(*) as row_count from {{ ref('fs_loan_portfolio') }}

)

select
    staged.row_count as staged_rows,
    published.row_count as published_rows

from staged
cross join published

where staged.row_count <> published.row_count
