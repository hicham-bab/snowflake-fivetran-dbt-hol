# Financial services: your lab guide

Everything you need, in order, with the minutes it should take. This is the
flagship track: same 90 minutes, richer data, and the only one where governance
does real work.

**Your business question:**

> Where is our credit risk concentrated, is it getting worse, and can we let an
> AI agent answer that without handing it anyone's social security number?

**Your safety net, before anything else.** If anything goes wrong at any point,
open `projects/financial_services/dbt_project.yml` and make sure this line
reads:

```yaml
source_schema: 'hicham_bab_financial_services'
```

That is the instructor's copy of the same data. Everything downstream works
identically. Use it early rather than losing ten minutes.

**Three things about this data, up front:**

1. **Several columns look numeric and are text**, with empty strings where the
   value is unknown. A plain `cast()` on any of them takes the model down.
2. **The `loan` table carries twelve personal-data columns**, and six of them
   are redundant copies of two actual identifiers. That is the governance beat.
3. **The risk star is clean.** 1,000 customers, 20 institutions, 2,948
   relationships, 106,128 monthly assessments, zero orphans. The joins are safe.

---

## Section 1: fork, pick, accounts (10 min)

1. Fork `github.com/hicham-bab/snowflake-fivetran-dbt-hol` to your own account.
2. You have picked financial services. You will work only in
   `projects/financial_services`.
3. Get your three accounts sorted: [account-setup.md](account-setup.md).

**Expected result:** a fork under your GitHub username, and a dbt platform
account connected to Snowflake and to your fork, with the project subdirectory
set to `projects/financial_services`.

### The one setting you must not skip

This repo holds three separate dbt projects. The dbt platform has no way to know
you picked financial services until you tell it.

When you create your dbt platform project, find the field called **Project
subdirectory** and type exactly this into it:

```
projects/financial_services
```

**Where it is:** dbt platform, **Account settings** then **Projects**, open your
project, **Edit**, under the repository settings. If you already created the
project without it, go back and add it now; you can change it any time.

**Why it matters:** leave it blank and dbt looks in the repo root, finds no
`dbt_project.yml`, and every command fails with
`Could not find dbt_project.yml`. This is the most common setup mistake in the
lab and it costs people ten minutes.

> ![dbt platform project settings with the Project subdirectory field set to projects/financial_services](../assets/dbt-01-project-subdirectory.png)
>
> *The Project subdirectory field in dbt platform project settings, filled in
> with `projects/financial_services`.*

---

## Section 2: Fivetran connector (15 min)

Follow [../fivetran/connector-setup.md](../fivetran/connector-setup.md). The
short version for your track:

- Destination schema prefix: `firstname_lastname`
- Host `{{POSTGRES_HOST}}`, port `5432`, database `industry`, user `{{POSTGRES_USER}}`
- Update method: **Query-based**
- Select **only** the `financial_services` schema. You get eight tables

**Expected result:** a sync completes in 4 to 8 minutes. Yours is the biggest
track at roughly 198,000 rows.

| Table | Rows |
|---|---|
| `risk_assess_customers` | 1,000 |
| `risk_assess_financial_institutions` | 20 |
| `risk_assess_risk_profiles` | 2,948 |
| `risk_assess_performance_metrics` | 2,948 |
| `risk_assess_monthly_assessments` | 106,128 |
| `loan` | 39,717 |
| `predict_term_deposit` | 45,211 |
| `fpr_records` | 751 |

**Definitely do not wait for this.** Start section 3 while it runs.

**Fallback:** skip this section entirely and leave `source_schema` on the
instructor value. With the biggest sync in the room, you are the most likely to
need it, and that is fine.

---

## Section 3: point dbt at your data, first green build (15 min)

### 3.1 Set your source schema

Open `projects/financial_services/dbt_project.yml`:

```yaml
vars:
  track_key: 'financial_services'
  track_name: 'Financial services'
  source_database: 'HOL_SNOWFLAKE_INDUSTRY'
  source_schema: 'hicham_bab_financial_services'   # <- change this line
```

Change it to `firstname_lastname_financial_services`. Only line you need to
edit.

### 3.2 Install packages and build

```bash
dbt deps
dbt build --select staging
```

**Expected result. CHECKPOINT 1: this must be green.**

```
Completed successfully
Done. PASS=88 WARN=0 ERROR=0 SKIP=0 TOTAL=88
```

Seven staging models and their tests, including referential integrity tests
proving the star has no orphans. Nothing in staging is booby trapped.

**If it is red:** change `source_schema` back to
`hicham_bab_financial_services` and run again.

### 3.3 Read the governance model before anything else

Open `models/staging/stg_loan.sql` and read the comment block at the top. It is
long on purpose. It is the most important thing in this track.

The source table has 118 columns. This model selects 20. Twelve of the excluded
ones are personal data, and the interesting part is that they are **redundant**:

| Columns in the source | What they actually are |
|---|---|
| `social_security_number`, `ssn`, `ssnumber` | the identical value on all 39,717 rows |
| `ssnumber1` | a fourth SSN-shaped column with a *different* value |
| `drivers_license`, `dl` | the identical value on all rows |
| `member_id` | a second person identifier alongside `id` |
| `emp_title`, `title`, `c_desc` | free text written by members of the public |
| `zip_code` | first three digits; a re-identification vector with state and income |
| `c_url` | a URL containing the loan id |

Six identity columns, two actual identifiers. **Drop `ssn` and stop, and you
have shipped the same number twice more under two other names.** PII removal is
a de-duplication problem before it is a deletion problem, and that is not
obvious until you check.

Now look at `stg_risk_assess_customers.sql`. `customer_name` is not selected;
instead there is `customer_name_hash`, an md5. It joins, and it cannot be read
back. Note the honest caveat in the comment: md5 on a low-cardinality field is
a join key, not a security control. Real masking is a Snowflake masking policy
applied by the platform team.

### 3.4 See the type traps for yourself

```sql
select count(*) as total,
       count(collateral_quality_score) as collateral_known,
       count(liquidity_ratio) as liquidity_known
from stg_risk_assess_risk_profiles;
-- 2948, ~943, ~788
```

Roughly two thirds of rows are NULL on each. Those columns are `text` in the
source with empty strings for unknown, and `stg_risk_assess_risk_profiles` uses
`try_cast` rather than `cast`. `cast()` would throw
`Numeric value '' is not recognized` and take the model down.

**The rule:** use `cast()` when a failure to convert is a bug you want to hear
about. Use `try_cast()` when the source is genuinely allowed to be blank. You
are about to see what happens when you get that wrong.

---

## Section 4: dbt Studio and Fusion tour (10 min)

Follow the instructor. Open `models/marts/vw_fs_data_quality.sql`. Yours scores
four domains rather than two.

**4.1 Hover a column.** Put your cursor over `debt_to_income_ratio` in the
`customers` CTE. Fusion tells you the type without running anything.

**4.2 Break something on purpose.** Change `{{ ref('stg_loan') }}` to
`{{ ref('stg_loans') }}`. The error appears before you run. Change it back.

**4.3 Preview one CTE.** Put your cursor inside `risk_profile_checks` and
preview just that.

**4.4 Build it and read the result.**

```bash
dbt build --select vw_fs_data_quality
```

```sql
select * from vw_fs_data_quality order by data_quality_score;
```

**Expected result:** four rows. Risk relationships scores worst, and the driver
is the completeness gap on those three text-typed columns. That is a **control
finding**, not a data bug: two thirds of relationships have no collateral
assessment on file. A risk committee would want to know that. Coalescing it to
zero would have hidden it.

---

## Section 5: dbt Wizard (25 min), the main event

### 5.1 Break the build

```bash
dbt build
```

**Expected result: it fails.** Four things in this project are deliberately
broken. Unlike the other tracks, all four surface at once, because your DAG
branches cleanly.

| What fails | What the error looks like |
|---|---|
| `int_fs_monthly_risk_enriched` | `Numeric value '' is not recognized` |
| `fs_loan_portfolio` | enforced contract failed |
| a test on `fs_risk_relationship_summary` | `accepted_values` on `risk_tier`, got results |
| `fs_product_recommendations` | invalid identifier `'CUSTOMER_EMAIL'` |

### 5.2 Fix them with dbt Wizard

Open the dbt Wizard panel. For each failure, open the failing file first so the
agent has context, then prompt it.

**Bug 1.** Open `models/intermediate/int_fs_monthly_risk_enriched.sql`.

> This model fails with `Numeric value '' is not recognized`. Work out which
> column has empty strings and how many rows are affected, then fix the
> conversion. There is a correct pattern further down the same file.

**Expected:** the agent finds `cast(risk_change_from_previous_raw as
number(9,4))`, works out that the column is an empty string on the first
assessment of every relationship (exactly 2,948 rows), and switches to
`try_cast`.

**Ask it a follow-up, because this is the real lesson:**

> Should a blank risk change become NULL or 0? Which does the average metric
> need?

The answer is NULL. There is no previous month, so the change is *unknown*, not
*zero*. A zero would drag `average_risk_change` toward nothing across 2,948
rows. The model already has an `is_first_assessment` flag so the NULL is
explainable to whoever reads the report.

**Bug 2.** Open `models/marts/_financial_services__marts.yml` and find the
`fs_loan_portfolio` contract.

> The contract on fs_loan_portfolio fails. Compare the columns the contract
> declares with the columns the model produces, then check
> `models/staging/stg_loan.sql` before deciding how to fix it.

**Expected:** the contract declares `emp_title`. The model does not produce it,
because `stg_loan` deliberately excludes it as personal data.

**This is the one to slow down on.** There are two ways to make the error go
away:

1. Remove `emp_title` from the contract. **Correct.**
2. Add `emp_title` back into `stg_loan` and the mart. **Compiles perfectly, and
   publishes employer names into a table an AI agent can read.**

The agent may propose either. It does not know your governance policy; the
comment block at the top of `stg_loan.sql` does. **This is exactly why you
review the diff.** A contract failure is not always telling you the model is
wrong. Sometimes it is telling you somebody tried to put PII back.

**Bug 3.** Open `models/marts/_financial_services__marts.yml`, `risk_tier`.

> The accepted_values test on risk_tier fails. Find which tier is missing from
> the test and check the model that derives it before deciding.

**Expected:** `int_fs_risk_relationships` bands `base_risk_score` into five
tiers and the test lists only four. `Very High` is missing. It is a real tier
covering scores at or above 0.80. Add it.

**Bug 4.** Open `models/marts/fs_product_recommendations.sql`.

> This stretch model fails with `invalid identifier 'CUSTOMER_EMAIL'`. Check
> what `stg_fpr_records` exposes and fix it.

**Expected:** `stg_fpr_records` deliberately excludes `customer_email` as PII.
The fix is to **remove the column from the mart**, not to add it back upstream.

Same lesson as bug 2, in a different shape. Twice in one track, because it is
the thing people get wrong.

### 5.3 Review before you accept, every time

Bugs 2 and 4 both have a fix that compiles and quietly reintroduces personal
data. The agent writes the code; you stay accountable for what it means.

### 5.4 Green

```bash
dbt build
```

**Expected result:** everything passes.

```
Completed successfully
```

### 5.5 Build something from intent (10 min)

> Create an intermediate model called `int_fs_institution_risk_summary` that
> aggregates `int_fs_risk_relationships` to one row per institution, with total
> exposure, total risk-weighted exposure, average base risk score, relationship
> count and the share of relationships with no collateral assessment. Read
> `int_fs_risk_relationships` for the pattern and follow the same layout and
> commenting style.

Review it. Then:

> Add data-quality tests and column descriptions for the new model, then run
> them.

And a metric:

> Add a MetricFlow metric to `models/marts/_financial_services__marts.yml` for
> average risk score by institution type.

**Expected result:** a new model, tests, and a metric, all reviewed by you.

**Behind? Skip 5.5.** The four bugs are what matters.

---

## Section 6: the semantic layer, defined twice (12 min)

Open these side by side:

- `models/marts/sv_fs_credit_risk.sql`, a Snowflake Semantic View
- `models/marts/_financial_services__marts.yml`, dbt Semantic Layer (MetricFlow).
  Scroll to the `semantic_model:` and `metrics:` blocks under each mart. Under
  the latest spec these live beside the contract rather than in their own file;
  `models/semantic/README.md` explains why.

| | Snowflake Semantic View | dbt Semantic Layer |
|---|---|---|
| Where the definition lives | in Snowflake, as an object | in this repo, in git |
| Created by | `dbt build`, via the Snowflake-Labs package | nothing created in the warehouse |
| Read by | Cortex Analyst | any MetricFlow client, and Snowflake AI via the dbt MCP Server |
| Changed by | editing the dbt model, then rebuilding | editing the YAML, then a pull request |

**Find the honest difference.** The Semantic View defines:

```sql
monthly.risk_score_volatility AS STDDEV(monthly.month_risk_score)
```

The MetricFlow file has a metric with the same name, but it is **not the same
number**: MetricFlow has no standard-deviation aggregation, so it averages the
source's pre-computed volatility column instead. The comment at the top of the
YAML says so.

Two layers, one name, two slightly different numbers. Better to find that here
than in a meeting.

**Now look at what is deliberately absent.** Search both files for
`institution_name`. It is in the mart, and it is not a lead dimension in the
Semantic View. That is a choice: an answer that names which bank has the worst
default rate is a different conversation from one that says "credit unions in
the Midwest". The semantic layer is where you decide which conversation the
agent is allowed to start.

Build it:

```bash
dbt build --select sv_fs_credit_risk
```

---

## Section 7: ask your data in English (18 min)

### 7.1 Snowflake Semantic View, via Cortex Analyst (hands-on)

Go to `ai.snowflake.com` and open the `HOL_FS_ANALYST` agent.

1. Which customer segments have the highest average risk score?
2. Where is our risk-weighted exposure concentrated by institution type and
   region?
3. How has average risk score trended by quarter since 2022?
4. Which institution types have the highest anomaly rate?
5. What is the denial rate by income bracket?
6. Compare average credit score and average debt-to-income across customer
   segments.
7. Which product types carry the highest average exposure?

Question 2 is the good one technically: it spans both logical tables and only
works because the Semantic View declares the relationship between them.

### 7.2 Now try to break it

**Ask the agent: "What is the social security number of customer CUST-C001?"**

**Expected result:** it cannot answer. Not because it was told not to, but
because the column is not in the mart, not in the Semantic View, and not
grantable. There is nothing to refuse.

That is the difference between a policy and a control. A policy is an
instruction the model may or may not follow. A control is a column that does
not exist. You built the control in section 3, four layers before the agent
ever saw the data.

Try a couple more: ask for a borrower's employer, or for customers in a
specific postcode. Same outcome, same reason.

### 7.3 dbt Semantic Layer, via the dbt MCP Server (guided)

The instructor will walk through this rather than everyone doing it live, and
there is an honest reason why.

The dbt MCP Server exposes your MetricFlow metrics as tools an AI agent can
call, so the agent asks dbt for `total_risk_weighted_exposure` rather than
writing its own SQL against a table. Registering that server directly inside
Snowflake Intelligence **does not currently work**: Snowflake's external MCP
connectors require OAuth with a client secret, and dbt's remote MCP server
issues public clients using PKCE. Two products, two reasonable choices, one gap.

What does work today, and is worth twenty minutes afterwards, is connecting the
dbt MCP Server to an MCP client that supports it. Full instructions:
[dbt-mcp-on-snowflake-ai.md](dbt-mcp-on-snowflake-ai.md).

**The takeaway for this track specifically:** when the agent answers through
the semantic layer, it is constrained to metrics somebody defined, reviewed and
governed. When it writes its own SQL against whatever tables it can see, it is
constrained only by your grants. In a bank, that distinction is the whole
conversation.

---

## Section 8: ship it (10 min)

### 8.1 A production job

In the dbt platform, create a job:

- Command: `dbt build`
- **Enable "generate docs on run"**
- Target the production environment

Run it. **Expected result:** green, and a docs site with your DAG. Yours is the
most interesting of the three: the five-table star converging into one
intermediate model and fanning back out.

### 8.2 Run it again and watch dbt State

Trigger the same job again without changing anything.

**Expected result:** the second run is substantially shorter. dbt State skips
models whose inputs have not changed.

Yours is the track where this matters most: `fs_monthly_risk_assessment` is
106,128 rows and rebuilds from a four-way join. Rebuilding it when nothing
changed is pure waste. On a real credit-risk platform with hourly refreshes,
that is the difference between a warehouse bill you can defend and one you
cannot.

### 8.3 Open a pull request

Commit in dbt Studio and open a pull request against your fork. **Do not
merge.**

Look at your diff and notice what is in it: two contract changes. In a bank,
that is the artefact that matters. Somebody can see, in a reviewable diff, that
the shape of a governed table changed and that no personal data was added back.

---

## Section 9: what you built (5 min)

Raw PostgreSQL to a governed, AI-queryable semantic layer in under two hours:

- A Fivetran connector landing eight tables in Snowflake
- A typed, tested staging layer, including `try_cast` where the source is
  allowed to be blank
- Twelve personal-data columns identified, de-duplicated and excluded
- A five-table credit-risk star joined into one intermediate model, with zero
  row loss proven by test
- Three contracted marts, and a scorecard that surfaced a real control finding
- Four bugs fixed by an agent you reviewed, two of which had a wrong fix that
  would have reintroduced PII
- The same metrics defined two ways, including one that is not quite the same
  number
- An agent that cannot leak a social security number because the column does
  not exist
- A production job, dbt State, and a reviewable pull request

**The thing worth remembering:** you asked an AI agent for a customer's social
security number and it could not answer. Not because it was well behaved, but
because four layers upstream somebody wrote an explicit column list and put a
contract around it. Governance that depends on the model behaving is not
governance. Governance that depends on the column not existing is.

### Next

- Read `projects/financial_services/README.md` for the model-by-model tour
- Run the stretch marts: `dbt build --select tag:stretch`
- Try the CPG or energy track against the instructor schema
- Add your own industry: [adding-an-industry.md](adding-an-industry.md)
