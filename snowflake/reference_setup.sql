-- ===========================================================================
-- Reference setup for the Fivetran, Snowflake and dbt hands-on lab
--
-- THIS IS A REFERENCE, NOT A SCRIPT TO RUN BLIND.
--
-- It is owned and adapted by the Snowflake team. Names, sizes and grant model
-- will all differ depending on the account. Read it, take what applies, and
-- read snowflake/GOTCHAS.md, which is where the actual value is. This file
-- creates objects; that file explains the four or five things that will
-- otherwise break the lab.
--
-- Idempotent: every statement is IF NOT EXISTS or OR REPLACE-safe, so it can
-- be re-run while you iterate.
--
-- Sized for roughly 30 attendees, three tracks, a two-hour session.
-- ===========================================================================

USE ROLE ACCOUNTADMIN;


-- ---------------------------------------------------------------------------
-- 1. Database
--
-- One database holds everything: the Fivetran-landed raw schemas (one per
-- attendee per track), the instructor fallback schemas, and the dbt
-- development schemas.
-- ---------------------------------------------------------------------------

CREATE DATABASE IF NOT EXISTS HOL_SNOWFLAKE_INDUSTRY
  COMMENT = 'Fivetran + Snowflake + dbt hands-on lab. Safe to drop after the session.';


-- ---------------------------------------------------------------------------
-- 2. Warehouses
--
-- Two, not one. Separate warehouses make ingest cost distinguishable from
-- transformation cost, and stop a frequently-polling Fivetran connector from
-- holding the dbt warehouse open. See GOTCHAS.md section 5.
--
-- XS is genuinely enough. The largest table in the lab is 106,128 rows.
-- ---------------------------------------------------------------------------

CREATE WAREHOUSE IF NOT EXISTS HOL_FIVETRAN_WH
  WAREHOUSE_SIZE = XSMALL
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE
  COMMENT = 'Fivetran ingest only. Kept separate for cost attribution.';

CREATE WAREHOUSE IF NOT EXISTS HOL_DBT_WH
  WAREHOUSE_SIZE = XSMALL
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE
  COMMENT = 'dbt builds and attendee queries.';


-- ---------------------------------------------------------------------------
-- 3. Roles
-- ---------------------------------------------------------------------------

CREATE ROLE IF NOT EXISTS HOL_FIVETRAN
  COMMENT = 'Fivetran destination role. Creates schemas and tables on sync.';

CREATE ROLE IF NOT EXISTS HOL_DBT
  COMMENT = 'dbt platform role. Reads raw, writes marts and semantic views.';

CREATE ROLE IF NOT EXISTS HOL_ATTENDEE
  COMMENT = 'Attendee role for Snowsight and Snowflake Intelligence. Read-only on data.';

GRANT ROLE HOL_FIVETRAN TO ROLE SYSADMIN;
GRANT ROLE HOL_DBT      TO ROLE SYSADMIN;
GRANT ROLE HOL_ATTENDEE TO ROLE SYSADMIN;


-- ---------------------------------------------------------------------------
-- 4. Service users
--
-- KEY-PAIR AUTHENTICATION, NOT PASSWORDS. This is not a preference.
--
-- Snowflake is in the final phase (August to October 2026) of blocking
-- single-factor password sign-ins. TYPE = SERVICE blocks password auth
-- outright, and TYPE = LEGACY_SERVICE can no longer be created. A
-- password-only service user will fail. See GOTCHAS.md section 1.
--
-- Generate the keys first:
--   openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out fivetran_key.p8 -nocrypt
--   openssl rsa -in fivetran_key.p8 -pubout -out fivetran_key.pub
--
-- Then paste the .pub body below with the BEGIN/END lines and all newlines
-- removed. Load the matching .p8 private key into Fivetran and the dbt
-- platform respectively.
-- ---------------------------------------------------------------------------

CREATE USER IF NOT EXISTS FIVETRAN_SVC
  TYPE = SERVICE
  DEFAULT_ROLE = HOL_FIVETRAN
  DEFAULT_WAREHOUSE = HOL_FIVETRAN_WH
  RSA_PUBLIC_KEY = '<<PASTE FIVETRAN_SVC PUBLIC KEY BODY>>'
  COMMENT = 'Fivetran destination service user. Key-pair auth only.';

CREATE USER IF NOT EXISTS DBT_SVC
  TYPE = SERVICE
  DEFAULT_ROLE = HOL_DBT
  DEFAULT_WAREHOUSE = HOL_DBT_WH
  RSA_PUBLIC_KEY = '<<PASTE DBT_SVC PUBLIC KEY BODY>>'
  COMMENT = 'dbt platform service user. Key-pair auth only.';

GRANT ROLE HOL_FIVETRAN TO USER FIVETRAN_SVC;
GRANT ROLE HOL_DBT      TO USER DBT_SVC;


-- ---------------------------------------------------------------------------
-- 5. Warehouse and database grants
-- ---------------------------------------------------------------------------

GRANT USAGE ON WAREHOUSE HOL_FIVETRAN_WH TO ROLE HOL_FIVETRAN;
GRANT USAGE ON WAREHOUSE HOL_DBT_WH      TO ROLE HOL_DBT;
GRANT USAGE ON WAREHOUSE HOL_DBT_WH      TO ROLE HOL_ATTENDEE;

GRANT USAGE ON DATABASE HOL_SNOWFLAKE_INDUSTRY TO ROLE HOL_FIVETRAN;
GRANT USAGE ON DATABASE HOL_SNOWFLAKE_INDUSTRY TO ROLE HOL_DBT;
GRANT USAGE ON DATABASE HOL_SNOWFLAKE_INDUSTRY TO ROLE HOL_ATTENDEE;

-- Fivetran creates one schema per attendee per track on first sync.
-- Leaving this out fails once per attendee. See GOTCHAS.md section 4.
GRANT CREATE SCHEMA ON DATABASE HOL_SNOWFLAKE_INDUSTRY TO ROLE HOL_FIVETRAN;

-- dbt creates a development schema per attendee, plus the target schema.
GRANT CREATE SCHEMA ON DATABASE HOL_SNOWFLAKE_INDUSTRY TO ROLE HOL_DBT;


-- ---------------------------------------------------------------------------
-- 6. THE GRANTS THAT ACTUALLY BREAK THE LAB
--
-- Fivetran creates new schemas and tables continuously. Without future grants,
-- dbt sources fail with "object does not exist" and the message tells you
-- nothing useful. Without grants on existing objects as well, the tables
-- Fivetran already created stay invisible, because future grants are not
-- retroactive.
--
-- You need both halves. See GOTCHAS.md section 2.
-- ---------------------------------------------------------------------------

-- Future objects
GRANT USAGE  ON FUTURE SCHEMAS IN DATABASE HOL_SNOWFLAKE_INDUSTRY TO ROLE HOL_DBT;
GRANT SELECT ON FUTURE TABLES  IN DATABASE HOL_SNOWFLAKE_INDUSTRY TO ROLE HOL_DBT;
GRANT SELECT ON FUTURE VIEWS   IN DATABASE HOL_SNOWFLAKE_INDUSTRY TO ROLE HOL_DBT;

GRANT USAGE  ON FUTURE SCHEMAS IN DATABASE HOL_SNOWFLAKE_INDUSTRY TO ROLE HOL_ATTENDEE;
GRANT SELECT ON FUTURE TABLES  IN DATABASE HOL_SNOWFLAKE_INDUSTRY TO ROLE HOL_ATTENDEE;
GRANT SELECT ON FUTURE VIEWS   IN DATABASE HOL_SNOWFLAKE_INDUSTRY TO ROLE HOL_ATTENDEE;

-- Existing objects
GRANT USAGE  ON ALL SCHEMAS IN DATABASE HOL_SNOWFLAKE_INDUSTRY TO ROLE HOL_DBT;
GRANT SELECT ON ALL TABLES  IN DATABASE HOL_SNOWFLAKE_INDUSTRY TO ROLE HOL_DBT;
GRANT SELECT ON ALL VIEWS   IN DATABASE HOL_SNOWFLAKE_INDUSTRY TO ROLE HOL_DBT;

GRANT USAGE  ON ALL SCHEMAS IN DATABASE HOL_SNOWFLAKE_INDUSTRY TO ROLE HOL_ATTENDEE;
GRANT SELECT ON ALL TABLES  IN DATABASE HOL_SNOWFLAKE_INDUSTRY TO ROLE HOL_ATTENDEE;
GRANT SELECT ON ALL VIEWS   IN DATABASE HOL_SNOWFLAKE_INDUSTRY TO ROLE HOL_ATTENDEE;

-- Check for schema-level future grants that would shadow the database-level
-- ones above. More specific wins, and it wins silently.
SHOW FUTURE GRANTS IN DATABASE HOL_SNOWFLAKE_INDUSTRY;


-- ---------------------------------------------------------------------------
-- 7. Instructor fallback schemas
--
-- The safety net the entire lab design leans on. Every attendee guide says
-- "if you are stuck, point source_schema here and keep going". If these are
-- missing or unreadable, a slow Fivetran sync stops being an inconvenience and
-- becomes the end of somebody's lab.
--
-- Populate them by running the Fivetran connector once with destination schema
-- prefix `hicham_bab`, selecting all three source schemas.
-- ---------------------------------------------------------------------------

CREATE SCHEMA IF NOT EXISTS HOL_SNOWFLAKE_INDUSTRY.hicham_bab_consumer_packaged_goods;
CREATE SCHEMA IF NOT EXISTS HOL_SNOWFLAKE_INDUSTRY.hicham_bab_energy;
CREATE SCHEMA IF NOT EXISTS HOL_SNOWFLAKE_INDUSTRY.hicham_bab_financial_services;

GRANT USAGE ON SCHEMA HOL_SNOWFLAKE_INDUSTRY.hicham_bab_consumer_packaged_goods TO ROLE HOL_DBT;
GRANT USAGE ON SCHEMA HOL_SNOWFLAKE_INDUSTRY.hicham_bab_energy                  TO ROLE HOL_DBT;
GRANT USAGE ON SCHEMA HOL_SNOWFLAKE_INDUSTRY.hicham_bab_financial_services      TO ROLE HOL_DBT;

GRANT USAGE ON SCHEMA HOL_SNOWFLAKE_INDUSTRY.hicham_bab_consumer_packaged_goods TO ROLE HOL_ATTENDEE;
GRANT USAGE ON SCHEMA HOL_SNOWFLAKE_INDUSTRY.hicham_bab_energy                  TO ROLE HOL_ATTENDEE;
GRANT USAGE ON SCHEMA HOL_SNOWFLAKE_INDUSTRY.hicham_bab_financial_services      TO ROLE HOL_ATTENDEE;


-- ---------------------------------------------------------------------------
-- 8. Cortex
--
-- Three things must be true before Cortex Analyst answers anything: the role,
-- the region, and Snowflake Intelligence being switched on. Trial accounts
-- routinely fail the second. See GOTCHAS.md section 7.
-- ---------------------------------------------------------------------------

GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE HOL_ATTENDEE;
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE HOL_DBT;

-- Only if the account region lacks the required models. ACCOUNTADMIN only,
-- account level only. Note the parameter name: CORTEX_ENABLED_CROSS_REGION.
-- Be deliberate: this sends inference outside the home geography.
-- ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'ANY_REGION';


-- ---------------------------------------------------------------------------
-- 9. Attendee users
--
-- Human users, so MFA applies. If attendees are using their own Snowflake
-- trial accounts instead, skip this section entirely.
--
-- Adapt the loop by hand or generate it; Snowflake has no CREATE USER loop.
-- ---------------------------------------------------------------------------

-- CREATE USER IF NOT EXISTS jane_doe
--   TYPE = PERSON
--   DEFAULT_ROLE = HOL_ATTENDEE
--   DEFAULT_WAREHOUSE = HOL_DBT_WH
--   MUST_CHANGE_PASSWORD = TRUE
--   PASSWORD = '<<one-time>>';
-- GRANT ROLE HOL_ATTENDEE TO USER jane_doe;


-- ---------------------------------------------------------------------------
-- 10. RUN THIS AFTER THE FIRST dbt JOB, NOT BEFORE
--
-- dbt creates the marts and the Semantic Views. They do not exist yet when
-- this file is first run, and Cortex Analyst cannot read what it has not been
-- granted. Substitute the dbt target schema.
--
-- Note the rebuild trap: CREATE OR REPLACE SEMANTIC VIEW drops the object and
-- every grant on it. Either set create_or_alter=true in the dbt model config,
-- or re-run these grants after each job. See GOTCHAS.md section 8.
-- ---------------------------------------------------------------------------

-- SET dbt_schema = 'dbt_hicham';
--
-- GRANT USAGE ON SCHEMA HOL_SNOWFLAKE_INDUSTRY.IDENTIFIER($dbt_schema) TO ROLE HOL_ATTENDEE;
--
-- GRANT SELECT ON ALL TABLES          IN SCHEMA HOL_SNOWFLAKE_INDUSTRY.IDENTIFIER($dbt_schema) TO ROLE HOL_ATTENDEE;
-- GRANT SELECT ON ALL VIEWS           IN SCHEMA HOL_SNOWFLAKE_INDUSTRY.IDENTIFIER($dbt_schema) TO ROLE HOL_ATTENDEE;
-- GRANT SELECT ON ALL SEMANTIC VIEWS  IN SCHEMA HOL_SNOWFLAKE_INDUSTRY.IDENTIFIER($dbt_schema) TO ROLE HOL_ATTENDEE;
--
-- GRANT SELECT ON FUTURE TABLES         IN SCHEMA HOL_SNOWFLAKE_INDUSTRY.IDENTIFIER($dbt_schema) TO ROLE HOL_ATTENDEE;
-- GRANT SELECT ON FUTURE VIEWS          IN SCHEMA HOL_SNOWFLAKE_INDUSTRY.IDENTIFIER($dbt_schema) TO ROLE HOL_ATTENDEE;
-- GRANT SELECT ON FUTURE SEMANTIC VIEWS IN SCHEMA HOL_SNOWFLAKE_INDUSTRY.IDENTIFIER($dbt_schema) TO ROLE HOL_ATTENDEE;


-- ---------------------------------------------------------------------------
-- 11. Verification
--
-- Run these AS THE TARGET ROLE. Running them as ACCOUNTADMIN proves nothing:
-- ACCOUNTADMIN can see everything and will happily tell you the lab is fine.
-- ---------------------------------------------------------------------------

-- USE ROLE HOL_DBT;
-- USE WAREHOUSE HOL_DBT_WH;
-- SELECT COUNT(*) FROM HOL_SNOWFLAKE_INDUSTRY.hicham_bab_consumer_packaged_goods.cpg_records;   -- expect 750
-- SELECT COUNT(*) FROM HOL_SNOWFLAKE_INDUSTRY.hicham_bab_energy.commodity_prices;               -- expect 5898
-- SELECT COUNT(*) FROM HOL_SNOWFLAKE_INDUSTRY.hicham_bab_financial_services.risk_assess_monthly_assessments; -- expect 106128

-- Confirm identifier casing. See GOTCHAS.md section 3.
-- SELECT table_schema, table_name, column_name
-- FROM HOL_SNOWFLAKE_INDUSTRY.information_schema.columns
-- WHERE table_name ILIKE 'cpg_records' LIMIT 5;

-- USE ROLE HOL_ATTENDEE;
-- SELECT COUNT(*) FROM HOL_SNOWFLAKE_INDUSTRY.hicham_bab_energy.fts_records;                    -- expect 750


-- ---------------------------------------------------------------------------
-- 12. Teardown
-- ---------------------------------------------------------------------------

-- ALTER WAREHOUSE HOL_FIVETRAN_WH SUSPEND;
-- ALTER WAREHOUSE HOL_DBT_WH SUSPEND;
-- DROP DATABASE IF EXISTS HOL_SNOWFLAKE_INDUSTRY;
-- DROP WAREHOUSE IF EXISTS HOL_FIVETRAN_WH;
-- DROP WAREHOUSE IF EXISTS HOL_DBT_WH;
-- DROP USER IF EXISTS FIVETRAN_SVC;
-- DROP USER IF EXISTS DBT_SVC;
-- DROP ROLE IF EXISTS HOL_FIVETRAN;
-- DROP ROLE IF EXISTS HOL_DBT;
-- DROP ROLE IF EXISTS HOL_ATTENDEE;
