# Snowflake setup gotchas for a Fivetran and dbt lab

**Audience: whoever on the Snowflake side is standing up the account for this
lab. Fifteen minutes of reading that will save an afternoon.**

None of this is about Snowflake being hard. It is about the specific seams
between Fivetran, dbt and Snowflake, which is where labs like this actually
break. They are ordered by how often they bite, not by how interesting they are.

Verified against Snowflake documentation in August 2026. Numbers 1 and 7 have
both moved recently; re-check them before each delivery.

---

## 1. Password-only service accounts are being switched off right now

This is first because the enforcement window is open as you read this.

Snowflake is deprecating single-factor password sign-ins in three phases. The
final phase, **August to October 2026**, enforces across all users and
accounts, and existing `TYPE = LEGACY_SERVICE` users are converted to
`TYPE = SERVICE`, which **blocks password authentication entirely**. From phase
2 (May to July 2026), `TYPE = LEGACY_SERVICE` is already an invalid option on
`CREATE USER` and `ALTER USER`.

Source: [Deprecation of single-factor password sign-ins](https://docs.snowflake.com/en/user-guide/security-mfa-rollout).

**What this means for you:** if you create the Fivetran and dbt service users
with a password and nothing else, they may work when you test them and stop
working before the lab. Use key-pair authentication.

```sql
-- Generate the key pair outside Snowflake:
--   openssl genrsa 2048 | openssl pkcs8 -topk8 -inform PEM -out fivetran_key.p8 -nocrypt
--   openssl rsa -in fivetran_key.p8 -pubout -out fivetran_key.pub
-- Then strip the BEGIN/END lines and all newlines from the .pub file.

CREATE USER IF NOT EXISTS FIVETRAN_SVC
  TYPE = SERVICE
  DEFAULT_ROLE = HOL_FIVETRAN
  DEFAULT_WAREHOUSE = HOL_FIVETRAN_WH
  RSA_PUBLIC_KEY = 'MIIBIjANBgkqh...';

CREATE USER IF NOT EXISTS DBT_SVC
  TYPE = SERVICE
  DEFAULT_ROLE = HOL_DBT
  DEFAULT_WAREHOUSE = HOL_DBT_WH
  RSA_PUBLIC_KEY = 'MIIBIjANBgkqh...';
```

**Where the private key goes:**

- **Fivetran:** on the Snowflake destination setup page, choose key-pair
  authentication and paste the contents of the `.p8` private key file.
- **dbt platform:** in the Snowflake connection, choose key-pair and paste the
  private key. If you generated it with a passphrase, dbt platform has a
  separate field for that. Generating without a passphrase (`-nocrypt` above)
  is simpler for a lab.

Two things people trip on. `RSA_PUBLIC_KEY` wants the base64 body only, with
the `-----BEGIN PUBLIC KEY-----` and `-----END PUBLIC KEY-----` lines and every
newline removed. And key rotation uses `RSA_PUBLIC_KEY_2`, which is worth
knowing but irrelevant for a one-day lab.

Programmatic access tokens (PATs) exist as a drop-in password replacement for
applications that cannot do key-pair. Key-pair is still the better answer for
both of these connectors.

---

## 2. Future grants, or dbt cannot see what Fivetran just created

**This is the single most common Fivetran-to-dbt breakage, and it presents as
the least helpful error message: "object does not exist, or operation cannot be
performed".**

Fivetran creates schemas and tables continuously. Every new table it writes is
owned by the Fivetran role and, unless you have said otherwise in advance, is
invisible to the dbt role. Grants on objects that exist today say nothing about
objects created tomorrow.

Two separate mistakes hide in here:

**Mistake one: no future grants at all.** You grant `SELECT` on the tables you
can see, the demo works, then Fivetran syncs again, creates a new table, and
dbt cannot read it.

**Mistake two: future grants only, forgetting that they are not retroactive.**
You add `ON FUTURE TABLES`, congratulate yourself, and the tables Fivetran
already created stay invisible. You need both.

```sql
-- Future schemas, at the database level. Needed because each attendee's
-- Fivetran connector creates a brand new schema.
GRANT USAGE ON FUTURE SCHEMAS IN DATABASE HOL_SNOWFLAKE_INDUSTRY TO ROLE HOL_DBT;
GRANT SELECT ON FUTURE TABLES  IN DATABASE HOL_SNOWFLAKE_INDUSTRY TO ROLE HOL_DBT;
GRANT SELECT ON FUTURE VIEWS   IN DATABASE HOL_SNOWFLAKE_INDUSTRY TO ROLE HOL_DBT;

-- And the same for what already exists. Future grants are NOT retroactive.
GRANT USAGE  ON ALL SCHEMAS IN DATABASE HOL_SNOWFLAKE_INDUSTRY TO ROLE HOL_DBT;
GRANT SELECT ON ALL TABLES  IN DATABASE HOL_SNOWFLAKE_INDUSTRY TO ROLE HOL_DBT;
GRANT SELECT ON ALL VIEWS   IN DATABASE HOL_SNOWFLAKE_INDUSTRY TO ROLE HOL_DBT;
```

One more trap: **database-level future grants and schema-level future grants
do not stack.** If someone has already set `ON FUTURE TABLES IN SCHEMA
<something>`, that more specific grant wins for that schema and the
database-level one is ignored there. Check with:

```sql
SHOW FUTURE GRANTS IN DATABASE HOL_SNOWFLAKE_INDUSTRY;
```

**Verify before the room fills up.** Run this as the dbt role, not as
ACCOUNTADMIN, which can see everything and will tell you nothing:

```sql
USE ROLE HOL_DBT;
SELECT COUNT(*) FROM HOL_SNOWFLAKE_INDUSTRY.hicham_bab_energy.fts_records;
```

---

## 3. Identifier casing

Snowflake folds unquoted identifiers to uppercase. Quoted identifiers keep
whatever case they were created with. Fivetran destinations do not all behave
the same way, and the failure mode is a flat "invalid identifier".

This repo sets quoting off, which matches a standard Fivetran Snowflake
destination that creates unquoted (therefore uppercase) objects:

```yaml
# projects/<track>/dbt_project.yml
quoting:
  database: false
  schema: false
  identifier: false
```

**Confirm which way your destination actually lands before the lab.** One
query settles it:

```sql
SELECT table_schema, table_name, column_name
FROM HOL_SNOWFLAKE_INDUSTRY.information_schema.columns
WHERE table_name ILIKE 'fts_records'
LIMIT 5;
```

If `table_name` comes back `FTS_RECORDS` and `column_name` comes back
`RECORD_ID`, the current setting is correct and nothing needs to change. If
they come back lowercase, they were created quoted, and every project needs
`quoting: identifier: true` plus quoted names in the sources YAML. Tell the
facilitator, because that is a change to all three projects and it is much
easier made the night before than in the room.

---

## 4. Fivetran destination privileges

The Fivetran role needs more than `SELECT`. It creates schemas on every new
connector, creates and alters tables on every schema change, and maintains its
own metadata schema.

```sql
GRANT USAGE ON WAREHOUSE HOL_FIVETRAN_WH   TO ROLE HOL_FIVETRAN;
GRANT USAGE ON DATABASE  HOL_SNOWFLAKE_INDUSTRY TO ROLE HOL_FIVETRAN;
GRANT CREATE SCHEMA ON DATABASE HOL_SNOWFLAKE_INDUSTRY TO ROLE HOL_FIVETRAN;
```

`CREATE SCHEMA` is the one people leave out, and with 30 attendees each
creating their own `firstname_lastname_*` schema, it fails 30 times.

**System columns.** Fivetran adds `_fivetran_synced` to every table, and
`_fivetran_deleted` when the connector is in soft-delete mode. This lab uses
query-based PostgreSQL replication, which cannot detect hard deletes, so
`_fivetran_deleted` may not appear. No model in this repo references it, on
purpose: a missing column would break every attendee simultaneously. If you
switch the connector to log-based replication later, the column appears and
downstream models should start filtering
`WHERE COALESCE(_fivetran_deleted, FALSE) = FALSE`.

Fivetran also creates a metadata schema in the destination. Leave it alone and
do not grant attendees write access to it.

---

## 5. Warehouse strategy, and the one that never suspends

Use two warehouses, not one:

```sql
CREATE WAREHOUSE IF NOT EXISTS HOL_FIVETRAN_WH
  WAREHOUSE_SIZE = XSMALL AUTO_SUSPEND = 60 AUTO_RESUME = TRUE INITIALLY_SUSPENDED = TRUE;

CREATE WAREHOUSE IF NOT EXISTS HOL_DBT_WH
  WAREHOUSE_SIZE = XSMALL AUTO_SUSPEND = 60 AUTO_RESUME = TRUE INITIALLY_SUSPENDED = TRUE;
```

Two reasons, one boring and one that costs money.

The boring one: cost attribution. With one shared warehouse you cannot answer
"what did ingestion cost versus transformation", which is the first question
anyone asks after a lab like this.

The one that costs money: **a warehouse serving a frequently-polling Fivetran
connector may never suspend.** Auto-suspend counts idle seconds. If a
query-based connector polls every minute and auto-suspend is 60 seconds, the
warehouse can stay warm indefinitely and bill continuously, including overnight
after everyone has gone home. Keeping Fivetran on its own warehouse means that
behaviour cannot silently keep the dbt warehouse alive too.

XS is genuinely enough. The largest table in this lab is 106,128 rows and the
whole DAG builds in seconds.

**After the lab:** suspend both, and consider dropping the attendee schemas.
Thirty people times three schemas adds up.

---

## 6. Network policies and IP allowlists

If the account has a network policy, both Fivetran and the dbt platform need to
be allowed through, and the failure mode is a connection that hangs and then
times out rather than one that says "blocked".

- **Fivetran** publishes egress IPs per destination region. They are shown on
  the destination setup page in the Fivetran UI; take them from there rather
  than from a blog post, because they are region-specific.
- **dbt platform** publishes its egress IPs per region as well, and you only
  need these if you are applying IP restrictions.

For a one-day lab in a Snowflake office, the pragmatic answer is usually to run
the lab account without a restrictive network policy. If the account is shared
with anything real, that is not an option, and PrivateLink is the enterprise
answer but is far too much setup for a workshop.

**Test this from outside the building.** A policy that allows the office IP
range will look fine when you test it in the office and fail for the Fivetran
service, which is nowhere near the office.

---

## 7. Cortex availability, region, and the role nobody grants

Three separate things have to be true before Cortex Analyst answers a question,
and trial accounts routinely fail the second one.

**The role.** Cortex functions require `SNOWFLAKE.CORTEX_USER`. It is granted
to `PUBLIC` by default in most accounts, but if someone has revoked it, or in a
hardened account, nothing works and the error is about privileges rather than
about Cortex.

```sql
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE HOL_ATTENDEE;
```

**The region.** Cortex models are not available in every region, and a trial
account signed up on the day lands wherever the person clicking the button
happened to land. If the model is not available locally, enable cross-region
inference. The parameter name is easy to get slightly wrong:

```sql
-- Note: CORTEX_ENABLED_CROSS_REGION, not CORTEX_ENABLE_CROSS_REGION.
-- ACCOUNTADMIN only. Cannot be set at user or session level.
ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'ANY_REGION';
```

Valid values include `ANY_REGION`, `AWS_GLOBAL`, `AZURE_GLOBAL`, `GCP_GLOBAL`,
geography-scoped values such as `AWS_US` and `AWS_EU`, and `DISABLED`. Source:
[Cross-region inference](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cross-region-inference).

Be deliberate about which value you pick. `ANY_REGION` will send inference
requests outside the account's home geography, which is a straightforward
conversation for a synthetic-data lab and a much longer one if anyone assumes
the same setting is fine in production.

**Snowflake Intelligence needs its own enablement.** It is not automatically on
just because Cortex functions work. Turn it on and confirm you can reach
`ai.snowflake.com` with the lab role well before the day.

**Flag region problems early.** If attendees create their own trial accounts on
the morning, some of them will land in a region without the models, and you
want to discover that at 09:05 rather than at 11:30 when the room reaches the
consumption section.

---

## 8. Semantic View and Cortex privileges

The Semantic Views in this lab are created by dbt, using the
[Snowflake-Labs/dbt_semantic_view](https://hub.getdbt.com/Snowflake-Labs/dbt_semantic_view/latest/)
package. That means they are owned by the dbt role, not by whoever is asking
questions in Snowflake Intelligence. Those are different identities and the
grants do not happen by themselves.

For Cortex Analyst to read a Semantic View, the querying role needs `SELECT` on
the Semantic View and `USAGE` on its database and schema, **plus** access to the
underlying tables the view references. A Semantic View does not launder
permissions: a role that cannot read `fs_monthly_risk_assessment` cannot get at
it through `sv_fs_credit_risk` either.

```sql
GRANT USAGE ON DATABASE HOL_SNOWFLAKE_INDUSTRY TO ROLE HOL_ATTENDEE;
GRANT USAGE ON SCHEMA   HOL_SNOWFLAKE_INDUSTRY.<dbt_target_schema> TO ROLE HOL_ATTENDEE;
GRANT SELECT ON ALL SEMANTIC VIEWS IN SCHEMA HOL_SNOWFLAKE_INDUSTRY.<dbt_target_schema> TO ROLE HOL_ATTENDEE;
GRANT SELECT ON ALL TABLES         IN SCHEMA HOL_SNOWFLAKE_INDUSTRY.<dbt_target_schema> TO ROLE HOL_ATTENDEE;

-- dbt rebuilds these on every run, so cover what it creates next time too.
GRANT SELECT ON FUTURE SEMANTIC VIEWS IN SCHEMA HOL_SNOWFLAKE_INDUSTRY.<dbt_target_schema> TO ROLE HOL_ATTENDEE;
GRANT SELECT ON FUTURE TABLES         IN SCHEMA HOL_SNOWFLAKE_INDUSTRY.<dbt_target_schema> TO ROLE HOL_ATTENDEE;
```

**The rebuild trap.** By default the package issues `CREATE OR REPLACE SEMANTIC
VIEW`, which drops the object and takes every grant on it with it. Attendees
then find that the agent worked before lunch and does not after. Two ways out:
set `create_or_alter=true` in the model config, or set `copy_grants=true`.
Note that Snowflake does not support `COPY GRANTS` with `CREATE OR ALTER`, so
these are alternatives rather than a belt-and-braces pair. For a lab, re-running
the grant statements after the dbt job is the simplest thing that works.

**Empty agent, no error.** If Cortex Analyst returns nothing at all rather than
an error, missing grants on the underlying tables is the first thing to check.
It frequently looks like a modelling problem and is almost always a grant.

---

## 9. One thing the Snowflake side cannot fix

Worth knowing so nobody spends the morning on it.

The lab wires the dbt Semantic Layer into an AI client through the dbt MCP
Server. Registering that server directly inside Snowflake Intelligence does not
currently work, and it is not a configuration problem on your side.

Snowflake's `CREATE EXTERNAL MCP SERVER` requires an API integration using
OAuth with a client ID and client secret, and the documentation states OAuth is
the only supported method for MCP server connections. dbt's remote MCP server
offers token auth via headers, or OAuth where manually registered clients use
PKCE **instead of** a client secret. Snowflake wants a confidential client;
dbt issues a public one. Separately, dbt's endpoint needs an
`x-dbt-prod-environment-id` header that the Snowflake connector has no
documented way to send.

`docs/dbt-mcp-on-snowflake-ai.md` covers this in full and gives the attendees a
path that works today. Nothing is required from the Snowflake side beyond the
Semantic View grants in section 8.

---

## Pre-flight checklist

Run through this the day before, not the morning of.

- [ ] `HOL_SNOWFLAKE_INDUSTRY` database exists
- [ ] `HOL_FIVETRAN_WH` and `HOL_DBT_WH` exist, XS, auto-suspend 60
- [ ] `FIVETRAN_SVC` and `DBT_SVC` are `TYPE = SERVICE` with `RSA_PUBLIC_KEY` set
- [ ] Both private keys are loaded into Fivetran and the dbt platform, and both connections test green
- [ ] Future grants set at the **database** level for the dbt role, and `SHOW FUTURE GRANTS` shows no conflicting schema-level grants
- [ ] Grants on **existing** objects set as well
- [ ] Fivetran role has `CREATE SCHEMA` on the database
- [ ] Instructor fallback schemas populated and readable **as the dbt role**: `hicham_bab_consumer_packaged_goods`, `hicham_bab_energy`, `hicham_bab_financial_services`
- [ ] Identifier casing confirmed against `information_schema.columns`, and `quoting` in all three projects matches
- [ ] `SNOWFLAKE.CORTEX_USER` granted to the attendee role
- [ ] Cortex model availability confirmed in the account region, or `CORTEX_ENABLED_CROSS_REGION` set
- [ ] Snowflake Intelligence enabled and reachable at `ai.snowflake.com` with the lab role
- [ ] Semantic View grants applied **after** the dbt job has run at least once
- [ ] One end-to-end question answered in Snowflake Intelligence, signed in as an attendee-role user rather than as ACCOUNTADMIN
