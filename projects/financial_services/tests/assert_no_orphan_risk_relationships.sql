-- Singular test: every relationship in the headline mart must resolve to a
-- customer and to an institution.
--
-- int_fs_risk_relationships uses inner joins, which is safe today because the
-- source has zero orphans in either direction. Inner joins are also how you
-- silently lose rows the day that stops being true: the model would not error,
-- it would just get smaller, and total exposure would quietly fall.
--
-- This test is the alarm on that door. It compares the relationship count in
-- the mart against the relationship count in staging, which no join has
-- touched.

with staged_relationships as (

    select count(*) as row_count from {{ ref('stg_risk_assess_risk_profiles') }}

),

published_relationships as (

    select count(*) as row_count from {{ ref('fs_risk_relationship_summary') }}

)

select
    staged_relationships.row_count as staged_rows,
    published_relationships.row_count as published_rows

from staged_relationships
cross join published_relationships

where staged_relationships.row_count <> published_relationships.row_count
