-- ===========================================================================
-- Financial services Semantic View: reference and verification
--
-- DO NOT MAINTAIN THE DDL HERE.
--
-- The definition lives in the dbt project, as a model:
--
--     projects/financial_services/models/marts/sv_fs_credit_risk.sql
--
-- Built by `dbt build` using the Snowflake-Labs/dbt_semantic_view package.
-- That model is the source of truth; editing the object by hand gets
-- overwritten on the next run.
--
-- GOVERNANCE, AND WHY IT MATTERS MORE HERE THAN IN THE OTHER TRACKS.
--
-- The source `loan` table carries twelve personal-data columns, including
-- three columns holding the identical social security number and two holding
-- the identical driver's licence. None of them reach this Semantic View,
-- because none of them reach the marts underneath it, because the dbt staging
-- model never selects them and every mart has an enforced contract pinning its
-- exact column list.
--
-- That ordering is the point. A Semantic View will happily describe whatever
-- columns it is given, and an agent will happily read them out to whoever
-- asked. The control has to sit upstream of the semantic layer, in the model
-- and the contract, not inside it.
-- ===========================================================================


-- ---------------------------------------------------------------------------
-- 1. What dbt creates
-- ---------------------------------------------------------------------------
--
-- Object: <database>.<dbt_target_schema>.SV_FS_CREDIT_RISK
--
-- Logical tables:
--   monthly       <- fs_monthly_risk_assessment    (106,128 rows, 2022-01 to 2024-11)
--   relationships <- fs_risk_relationship_summary  (2,948 rows, snapshot)
--
-- Relationship:
--   monthly (customer_id, institution_id) REFERENCES relationships (customer_id, institution_id)
--
-- That join is what lets a single natural-language question span time and the
-- conformed dimensions: "how did risk trend for high net worth customers at
-- credit unions in the Midwest" needs both tables and nobody should have to
-- write the join.
--
-- Metrics:
--   monthly.average_risk_score, risk_score_volatility, average_fraud_probability,
--   average_risk_change, anomaly_rate, denial_rate, approval_rate,
--   deterioration_rate, total_transaction_volume, assessment_count
--   relationships.total_exposure, average_exposure,
--   total_risk_weighted_exposure, average_credit_score, average_debt_to_income,
--   average_risk_adjusted_return, average_customer_value_score,
--   relationship_count
--
-- Dimensions:
--   time:         assessment_date, assessment_year
--   monthly risk: risk_level, anomaly_type, approval_recommendation
--   customer:     customer_segment, income_bracket, credit_score_range,
--                 education_level, employment_sector
--   institution:  institution_type, institution_size, region,
--                 regulatory_rating, risk_appetite_band, primary_risk_model
--   relationship: product_type, risk_tier, exposure_band, relationship_stage,
--                 risk_pattern, customer_value_category
--
-- Note what is NOT a dimension: institution_name. It exists in the mart for
-- drill-down but is kept out of the Semantic View's lead dimensions. An answer
-- that names which bank has the worst default rate is a different conversation
-- from one that says "credit unions in the Midwest", and the semantic layer is
-- where you decide which conversation the agent is allowed to start.


-- ---------------------------------------------------------------------------
-- 2. Verify dbt built it
-- ---------------------------------------------------------------------------

SHOW SEMANTIC VIEWS IN SCHEMA HOL_SNOWFLAKE_INDUSTRY.<dbt_target_schema>;

DESCRIBE SEMANTIC VIEW HOL_SNOWFLAKE_INDUSTRY.<dbt_target_schema>.SV_FS_CREDIT_RISK;


-- ---------------------------------------------------------------------------
-- 3. Confirm no personal data is exposed
--
-- Worth running in front of a risk or compliance stakeholder. Expect zero rows.
-- ---------------------------------------------------------------------------

SELECT column_name, table_name
FROM HOL_SNOWFLAKE_INDUSTRY.information_schema.columns
WHERE table_schema = upper('<dbt_target_schema>')
  AND upper(column_name) IN (
      'SSN', 'SSNUMBER', 'SSNUMBER1', 'SOCIAL_SECURITY_NUMBER',
      'DL', 'DRIVERS_LICENSE', 'MEMBER_ID',
      'EMP_TITLE', 'ZIP_CODE', 'C_URL', 'C_DESC',
      'CUSTOMER_NAME', 'CUSTOMER_EMAIL'
  );


-- ---------------------------------------------------------------------------
-- 4. Query it directly, without an agent
-- ---------------------------------------------------------------------------

-- Which customer segments carry the most risk.
SELECT *
FROM SEMANTIC_VIEW(
    HOL_SNOWFLAKE_INDUSTRY.<dbt_target_schema>.SV_FS_CREDIT_RISK
    METRICS    monthly.average_risk_score, monthly.anomaly_rate, monthly.denial_rate
    DIMENSIONS relationships.customer_segment
)
ORDER BY 2 DESC;

-- Where the capital at risk actually sits. This one crosses both logical
-- tables, so it exercises the relationship.
SELECT *
FROM SEMANTIC_VIEW(
    HOL_SNOWFLAKE_INDUSTRY.<dbt_target_schema>.SV_FS_CREDIT_RISK
    METRICS    relationships.total_risk_weighted_exposure, relationships.relationship_count
    DIMENSIONS relationships.institution_type, relationships.region
)
ORDER BY 3 DESC
LIMIT 20;


-- ---------------------------------------------------------------------------
-- 5. Grants
--
-- Run AFTER the dbt job. See ../GOTCHAS.md section 8 for the rebuild trap.
-- ---------------------------------------------------------------------------

GRANT USAGE  ON DATABASE HOL_SNOWFLAKE_INDUSTRY TO ROLE HOL_ATTENDEE;
GRANT USAGE  ON SCHEMA   HOL_SNOWFLAKE_INDUSTRY.<dbt_target_schema> TO ROLE HOL_ATTENDEE;
GRANT SELECT ON SEMANTIC VIEW HOL_SNOWFLAKE_INDUSTRY.<dbt_target_schema>.SV_FS_CREDIT_RISK TO ROLE HOL_ATTENDEE;

-- The underlying tables, or Cortex Analyst returns nothing rather than erroring.
GRANT SELECT ON TABLE HOL_SNOWFLAKE_INDUSTRY.<dbt_target_schema>.FS_MONTHLY_RISK_ASSESSMENT   TO ROLE HOL_ATTENDEE;
GRANT SELECT ON TABLE HOL_SNOWFLAKE_INDUSTRY.<dbt_target_schema>.FS_RISK_RELATIONSHIP_SUMMARY TO ROLE HOL_ATTENDEE;

-- Deliberately NOT granted to the attendee role: nothing extra is needed, but
-- if you add the loan mart to an agent later, grant FS_LOAN_PORTFOLIO too and
-- re-run the check in section 3 first.
