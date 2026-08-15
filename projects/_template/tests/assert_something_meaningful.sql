-- RENAME THIS FILE to assert_<what_it_checks>.sql
--
-- A singular test is just a select. dbt runs it and fails if it returns rows.
--
-- Ship two or three per track, and make them guard the things a generic test
-- cannot: an invariant that only holds because of a decision somebody made.
--
-- Good examples from the other tracks:
--   energy  assert_maintenance_logs_are_deduplicated.sql
--           the only thing standing between a union and doubled costs
--   cpg     assert_cancelled_orders_have_no_recognised_revenue.sql
--           the business rule that makes the revenue column trustworthy
--   fs      assert_no_orphan_risk_relationships.sql
--           inner joins silently lose rows; this notices
--
-- ALWAYS use ref(). A singular test with no ref() has no place in the DAG and
-- dbt cannot order it correctly.

select
    <key_column>,
    <evidence_column>

from {{ ref('<model_name>') }}

where <the_condition_that_should_never_be_true>
