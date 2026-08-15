# Fivetran connector setup

**Time: 20 minutes, most of which is the sync running while you do something
else.**

You will create one connector from a Google Cloud SQL for PostgreSQL database
into the shared Snowflake destination, and select only the schema for your
track. The source database, the Snowflake destination and the warehouse are
already built. You are not standing up infrastructure; you are wiring two
existing things together and watching rows land.

---

## Before you start

You need three things from the instructor, all on the lab credentials card:

| What | Where it comes from |
|---|---|
| Fivetran workshop invite | Sent to your email, or `{{FIVETRAN_WORKSHOP_URL}}` |
| Lab credentials card | `{{LAB_CREDENTIALS_URL}}`, passcode `{{PASSCODE}}` |
| Source database password | On the credentials card. Not in this repo, on purpose |

**If your Fivetran account has not arrived, skip this whole page.** Go straight
to your track's guide and leave `source_schema` in `dbt_project.yml` set to the
instructor schema. You lose nothing except watching the sync bar move. You can
come back at the end if there is time.

---

## Step 1: accept the invite and sign in (2 min)

1. Open the Fivetran invite email and accept it, or go to
   `{{FIVETRAN_WORKSHOP_URL}}`.
2. Set your password and sign in.
3. You will land in the workshop destination group. Do not create a new
   destination. The Snowflake destination is already configured and connected.

**Expected result:** you can see a destination in the left-hand nav with at
least one existing connector, and a **Add connector** button available.

---

## Step 2: create the PostgreSQL connector (5 min)

Click **Add connector**, search for **PostgreSQL**, and select it.

### Destination schema prefix

Fivetran asks for a **destination schema prefix** before anything else. This is
the single most important field on the page, because it is what keeps your data
separate from the other 29 people in the room.

```
firstname_lastname
```

All lowercase, underscore separated, no spaces. For example `jane_doe`.

Fivetran will create schemas named `<your prefix>_<source schema>`. So Jane Doe
selecting the energy schema gets `jane_doe_energy`. Write your prefix down; you
will type it into `dbt_project.yml` in a few minutes.

### Connection details

| Field | Value |
|---|---|
| Host | `{{POSTGRES_HOST}}` |
| Port | `5432` |
| Database | `industry` |
| User | `{{POSTGRES_USER}}` |
| Password | `{{POSTGRES_PASSWORD}}` (on the credentials card) |
| Connection method | Connect directly |
| Update method | **Query-based** |

Leave everything else at its default.

**On update method:** query-based means Fivetran polls the source with a query
rather than reading the write-ahead log. It is the right choice here because
the lab source is a read-only replica with no logical replication slot. One
consequence worth knowing: query-based replication cannot detect hard deletes,
so you may not see a `_fivetran_deleted` column on these tables. Nothing in
this lab depends on it.

Click **Save & Test**.

**Expected result:** a green **All connection tests passed** panel, after
roughly 20 to 40 seconds. If it fails, see troubleshooting at the bottom.

---

## Step 3: select only your track's schema (3 min)

Fivetran now shows you the full schema list from the source database. There are
26 schemas. **Select exactly one.**

| Your track | Select this schema | Tables you will get |
|---|---|---|
| Consumer packaged goods | `consumer_packaged_goods` | `cpg_records` |
| Energy | `energy` | `commodity_prices`, `fts_records`, `loglynx` |
| Financial services | `financial_services` | 8 tables including the five `risk_assess_*` |

1. Click **Block all** at the top to deselect everything.
2. Find your schema and enable it.
3. Leave every table inside it enabled.
4. Set schema change handling to **Allow all**.

**Why only one:** syncing all 26 schemas takes far longer than the lab has,
and you will only model one of them. If you accidentally enable extras, block
them and re-save before starting the sync.

> **CPG attendees:** you may see `cpg_records_orig` and `cpg_stockout_rates`
> listed. Leave them enabled or disable them, it makes no difference. The lab
> source user has no `SELECT` privilege on either, so they will not sync.
> Only `cpg_records` will arrive. That is expected, not a failure.

Click **Save & Continue**, then **Start Initial Sync**.

---

## Step 4: while the sync runs, start on dbt (10 min)

**Do not sit and watch this.** Expected sync times:

| Track | Rows | Typical sync |
|---|---|---|
| Consumer packaged goods | 750 | under 2 minutes |
| Energy | 7,398 | 2 to 4 minutes |
| Financial services | ~198,000 | 4 to 8 minutes |

Open your track's attendee guide now and work through the dbt platform setup
while this finishes. Come back when the connector shows a completed sync.

---

## Step 5: verify the data landed (3 min)

In Snowsight, run this. Replace the schema with yours.

```sql
-- CPG
select count(*) as row_count, max(_fivetran_synced) as last_synced
from HOL_SNOWFLAKE_INDUSTRY.firstname_lastname_consumer_packaged_goods.cpg_records;

-- Energy
select 'commodity_prices' as table_name, count(*) as row_count, max(_fivetran_synced) as last_synced
from HOL_SNOWFLAKE_INDUSTRY.firstname_lastname_energy.commodity_prices
union all
select 'fts_records', count(*), max(_fivetran_synced)
from HOL_SNOWFLAKE_INDUSTRY.firstname_lastname_energy.fts_records
union all
select 'loglynx', count(*), max(_fivetran_synced)
from HOL_SNOWFLAKE_INDUSTRY.firstname_lastname_energy.loglynx;

-- Financial services
select 'risk_assess_customers' as table_name, count(*) as row_count, max(_fivetran_synced) as last_synced
from HOL_SNOWFLAKE_INDUSTRY.firstname_lastname_financial_services.risk_assess_customers
union all
select 'risk_assess_monthly_assessments', count(*), max(_fivetran_synced)
from HOL_SNOWFLAKE_INDUSTRY.firstname_lastname_financial_services.risk_assess_monthly_assessments
union all
select 'loan', count(*), max(_fivetran_synced)
from HOL_SNOWFLAKE_INDUSTRY.firstname_lastname_financial_services.loan;
```

**Expected row counts.** If yours match, you are done here.

| Table | Rows |
|---|---|
| `cpg_records` | 750 |
| `commodity_prices` | 5,898 |
| `fts_records` | 750 |
| `loglynx` | 750 |
| `risk_assess_customers` | 1,000 |
| `risk_assess_financial_institutions` | 20 |
| `risk_assess_risk_profiles` | 2,948 |
| `risk_assess_performance_metrics` | 2,948 |
| `risk_assess_monthly_assessments` | 106,128 |
| `loan` | 39,717 |
| `predict_term_deposit` | 45,211 |
| `fpr_records` | 751 |

Notice `_fivetran_synced` on every row. Fivetran adds it; it is not in the
source. Your staging models carry it through as a load-audit column so you can
always answer "when did this row last change".

---

## Step 6: point dbt at your own schema (1 min)

Open your track's `dbt_project.yml` and change one line:

```yaml
vars:
  source_schema: 'firstname_lastname_energy'    # was 'hicham_bab_energy'
```

Run `dbt build --select staging`. If it is green, you are running on data you
ingested yourself.

**If anything goes wrong here, change that one line back.** The instructor
schema holds the same data and every downstream step behaves identically. Do
not spend lab time debugging a sync.

---

## Troubleshooting

**"Save & Test" fails on connection.**
Check host and port first, they are the usual culprits. If the tests hang
rather than fail, the account may have an IP allowlist that does not include
Fivetran's egress ranges; that is an instructor problem, not yours. Flag it and
move on with the instructor schema.

**Sync starts but no tables appear in Snowflake.**
Almost always a grant problem on the Snowflake side rather than anything you
did. See `snowflake/GOTCHAS.md` gotcha 2: future grants are not retroactive, so
a role that can see today's tables cannot necessarily see the ones Fivetran
created five minutes ago. Tell the instructor and use the instructor schema.

**Tables appear but dbt says "object does not exist".**
Two candidates. Either the same future-grants problem, or an identifier casing
mismatch between what Fivetran wrote and what dbt is asking for. See
`snowflake/GOTCHAS.md` gotcha 3.

**Sync is still running after 10 minutes.**
Financial services is the biggest track at around 198,000 rows and can take
longer on a busy shared warehouse. Switch to the instructor schema, keep going,
and check back at the end.

**I used the wrong schema prefix.**
Easiest fix is to leave it. Point `source_schema` at whatever Fivetran actually
created; the name does not matter to dbt as long as the two agree.
