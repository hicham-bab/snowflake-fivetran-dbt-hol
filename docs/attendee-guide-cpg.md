# Consumer packaged goods: your lab guide

Everything you need, in order, with the minutes it should take. If you fall
behind, every section tells you how to skip without breaking anything.

**Your business question:**

> Where are we losing money on this range, and is it a demand problem or a
> supply problem?

**Your safety net, before anything else.** If anything goes wrong at any point,
open `projects/cpg/dbt_project.yml` and make sure this line reads:

```yaml
source_schema: 'hicham_bab_consumer_packaged_goods'
```

That is the instructor's copy of the same data. Everything downstream works
identically. Use it early rather than losing ten minutes.

---

## Section 1: fork, pick, accounts (10 min)

1. Fork `github.com/hicham-bab/snowflake-fivetran-dbt-hol` to your own account.
2. You have picked consumer packaged goods. You will work only in
   `projects/cpg`.
3. Get your three accounts sorted: [account-setup.md](account-setup.md).

**Expected result:** a fork under your GitHub username, and a dbt platform
account connected to Snowflake and to your fork, with the project subdirectory
set to `projects/cpg`.

### The one setting you must not skip

This repo holds three separate dbt projects. The dbt platform has no way to know
you picked consumer packaged goods until you tell it.

When you create your dbt platform project, find the field called **Project
subdirectory** and type exactly this into it:

```
projects/cpg
```

**Where it is:** dbt platform, **Account settings** then **Projects**, open your
project, **Edit**, under the repository settings. If you already created the
project without it, go back and add it now; you can change it any time.

**Why it matters:** leave it blank and dbt looks in the repo root, finds no
`dbt_project.yml`, and every command fails with
`Could not find dbt_project.yml`. This is the most common setup mistake in the
lab and it costs people ten minutes.

> ![dbt platform project settings with the Project subdirectory field set to projects/cpg](../assets/dbt-01-project-subdirectory.png)
>
> *The Project subdirectory field in dbt platform project settings, filled in
> with `projects/cpg`.*

---

## Section 2: Fivetran connector (15 min)

Follow [../fivetran/connector-setup.md](../fivetran/connector-setup.md). The
short version for your track:

- Destination schema prefix: `firstname_lastname`
- Host `{{POSTGRES_HOST}}`, port `5432`, database `industry`, user `{{POSTGRES_USER}}`
- Update method: **Query-based**
- Select **only** the `consumer_packaged_goods` schema

**Expected result:** a sync completes in under 2 minutes and
`firstname_lastname_consumer_packaged_goods.cpg_records` holds **750 rows**.

```sql
select count(*) from HOL_SNOWFLAKE_INDUSTRY.firstname_lastname_consumer_packaged_goods.cpg_records;
-- 750
```

> You may see `cpg_records_orig` and `cpg_stockout_rates` in the table list.
> They will not sync: the lab source user has no read permission on them. That
> is expected, not a failure. You only need `cpg_records`.

**Do not wait for this.** Start section 3 while it runs.

**Fallback:** skip this section entirely and leave `source_schema` on the
instructor value.

---

## Section 3: point dbt at your data, first green build (15 min)

### 3.1 Set your source schema

Open `projects/cpg/dbt_project.yml`. There is one block you need, near the top:

```yaml
vars:
  track_key: 'cpg'
  track_name: 'Consumer packaged goods'
  source_database: 'HOL_SNOWFLAKE_INDUSTRY'
  source_schema: 'hicham_bab_consumer_packaged_goods'   # <- change this line
```

Change `source_schema` to your own: `firstname_lastname_consumer_packaged_goods`.

That is the only line in the whole project you need to edit. Everything else
reads from it.

### 3.2 Install packages and build

```bash
dbt deps
dbt build --select staging
```

**Expected result. CHECKPOINT 1: this must be green.**

```
Completed successfully
Done. PASS=24 WARN=0 ERROR=0 SKIP=0 TOTAL=24
```

One model (`stg_cpg_records`) and its tests. Nothing in staging is booby
trapped; if this is red, it is your `source_schema` or your sync, not the code.

**If it is red:** change `source_schema` back to
`hicham_bab_consumer_packaged_goods` and run it again. Do not debug your sync
during the lab.

### 3.3 Look at what you built

```sql
select * from stg_cpg_records limit 20;
```

Notice what staging did. `order_date` was a VARCHAR in the raw feed because the
source Postgres column is `text`; it is a real `DATE` now.
`price_optimization_flag` was the string `'TRUE'`; it is a boolean called
`is_price_optimized`. And `customer_ltv` was renamed to
`customer_lifetime_value`, which will matter in about fifteen minutes.

---

## Section 4: dbt Studio and Fusion tour (10 min)

Follow the instructor. Open `models/marts/vw_cpg_data_quality.sql`. It is
built as a chain of small CTEs specifically so you can poke at it.

**4.1 Hover a column.** Put your cursor over `stockout_rate` in the `base` CTE.
Fusion tells you the type without running anything, because it has parsed the
whole project and knows what staging produced.

**4.2 Break something on purpose.** Change `{{ ref('stg_cpg_records') }}` to
`{{ ref('stg_cpg_record') }}`. The error appears immediately, before you run
anything. Change it back.

**4.3 Preview one CTE.** Put your cursor inside the `consistency` CTE and
preview just that. You get its output without building the model.

**4.4 Now build it and read the result.**

```bash
dbt build --select vw_cpg_data_quality
```

```sql
select * from vw_cpg_data_quality order by data_quality_score;
```

**Expected result:** 10 rows, one per product category. Completeness and
validity score 100. Consistency scores around 74, and that is the interesting
part. Three things drag it down:

- **192 cancelled orders still carry a value** in `order_total`. Anyone summing
  `order_total` overstates revenue by about a quarter. That is why the mart has
  a separate `recognised_revenue` column.
- **8 products have a rating above 4.5 from fewer than 10 reviews.**
- **373 orders were placed after the price optimisation that supposedly
  informed them.**

None of these are bugs in the code. They are real properties of the data, and
the scorecard exists to make them visible rather than letting them turn up in
somebody's board pack.

---

## Section 5: dbt Wizard (25 min), the main event

### 5.1 Break the build

```bash
dbt build
```

**Expected result: it fails.** Four things in this project are deliberately
broken. You are going to fix them by talking to the agent, not by reading the
answers.

You should see three failures in this first run:

| What fails | What the error looks like |
|---|---|
| `int_cpg_order_performance` | invalid identifier `'CUSTOMER_LTV'` |
| `cpg_product_inventory_health` | invalid identifier `'INVENTORY_COVERAGE_RATE'` |
| a test on `vw_cpg_data_quality` | `Got 10 results, configured to fail if != 0` |

### 5.2 Fix them with dbt Wizard

Open the dbt Wizard panel in dbt Studio. For each failure, open the failing
file first so the agent has context, then prompt it.

**Bug 1.** Open `models/intermediate/int_cpg_order_performance.sql`.

> This model fails with `invalid identifier 'CUSTOMER_LTV'`. Look at the
> staging model it selects from and find and fix the issue.

**Expected:** the agent finds that `stg_cpg_records` renames the raw
`customer_ltv` to `customer_lifetime_value`, and proposes that change.

**Bug 2.** Open `models/marts/cpg_product_inventory_health.sql`.

> This model fails with `invalid identifier 'INVENTORY_COVERAGE_RATE'`. Check
> the column names `int_cpg_inventory_health` actually produces and fix it.

**Expected:** the agent finds `inventory_coverage_ratio` in the intermediate
model and corrects the near-miss name.

**Bug 3.** Open `models/marts/_cpg__marts.yml`.

> The accepted_range test on data_quality_score fails for all 10 categories.
> Look at the actual scores and tell me whether the data is wrong or the
> threshold is wrong, then fix whichever it is.

**Expected:** the agent works out that real scores sit around 91 to 92, that
nothing is wrong with the data, and that a minimum of 95 was never achievable.
The right fix is a threshold the business can actually hold to, around 85.

**This is the important one to think about.** A failing test does not always
mean the data is broken. Sometimes the test is the thing that is wrong, and
deciding which is a judgement call the agent should help you make, not make for
you.

### 5.3 Review before you accept, every time

dbt Wizard proposes a diff. **Read it before accepting.** This is the whole
point of the exercise: the agent writes the code, you stay accountable for it.

On bug 3 in particular, the agent may suggest several thresholds. It does not
know your data contract. You do.

### 5.4 Run again, meet the fourth

```bash
dbt build
```

**Expected result:** a new failure that could not appear before, because its
model would not compile.

```
This model has an enforced contract that failed.
```

`cpg_order_performance` produces `customer_lifetime_value` and its contract
expects `customer_ltv`.

> The contract on cpg_order_performance fails. Compare the columns the model
> produces with the columns the contract declares, and fix the mismatch.

**This is the lesson bug 1 was setting up.** You renamed the column in the
model. The contract is a separate promise about the shape of that table, and it
has to be updated too. That is not friction; it is the contract doing its job.
If it had not failed, a downstream consumer would have found out instead.

### 5.5 Green

```bash
dbt build
```

**Expected result:** everything passes.

```
Completed successfully
```

### 5.6 Build something from intent (10 min)

Repair is only half of what the agent is for. Now build something new.

> Create an intermediate model called `int_cpg_price_opportunity` that flags
> products where a price decrease was recommended, the product has high
> elasticity (above 0.7) and stockout risk is Low. Read
> `int_cpg_inventory_health` for the pattern and follow the same layout and
> commenting style.

Review what it produces. Then:

> Add data-quality tests and column descriptions for the new model in
> `_cpg__marts.yml`, then run them.

And a metric:

> Add a MetricFlow metric to `models/marts/_cpg__marts.yml` for the average price
> elasticity of products flagged as a price opportunity.

**Expected result:** a new model, tests, and a metric, all written by the agent
and reviewed by you. Note how much of the surrounding convention it picked up
from the existing files: that is why the project comments so heavily.

**Behind? Skip 5.6.** Fixing the four bugs is the section that matters.

---

## Section 6: the semantic layer, defined twice (12 min)

Open these two files side by side:

- `models/marts/sv_cpg_commercial_performance.sql`, a Snowflake Semantic View
- `models/marts/_cpg__marts.yml`, dbt Semantic Layer specs (MetricFlow).
  Scroll to the `semantic_model:` and `metrics:` blocks under each mart. Under
  the latest spec these live beside the contract rather than in their own file;
  `models/semantic/README.md` explains why.

They describe the same business. Find `total_recognised_revenue` in both.

| | Snowflake Semantic View | dbt Semantic Layer |
|---|---|---|
| Where the definition lives | in Snowflake, as an object | in this repo, in git |
| Created by | `dbt build`, via the Snowflake-Labs package | nothing is created in the warehouse |
| Read by | Cortex Analyst | any MetricFlow client, and Snowflake AI via the dbt MCP Server |
| Changed by | editing the dbt model, then rebuilding | editing the YAML, then a pull request |
| Also usable from | anything that can query Snowflake | any tool that speaks to the dbt Semantic Layer |

**The question is not which one wins.** It is where the definition of revenue
should live and who else needs to read it. If everything you own is in
Snowflake, the Semantic View is closer to the data. If revenue also has to mean
the same thing in a BI tool, a notebook and a Slack bot, the definition wants
to live upstream of all of them.

Notice the synonyms in the Semantic View:

```sql
orders.total_recognised_revenue AS SUM(orders.line_recognised_revenue)
    WITH SYNONYMS = ('revenue', 'net revenue', 'recognised revenue')
    COMMENT = 'Sum of order value excluding cancelled orders. Use this for revenue.'
```

Those are not documentation. That is how Cortex Analyst maps somebody typing
"how much revenue" onto the right column rather than onto `total_order_value`,
which would be wrong by about a quarter.

Build it:

```bash
dbt build --select sv_cpg_commercial_performance
```

---

## Section 7: ask your data in English (18 min)

### 7.1 Snowflake Semantic View, via Cortex Analyst (hands-on)

Go to `ai.snowflake.com` and open the `HOL_CPG_ANALYST` agent.

Try these:

1. Which product categories have the highest stockout rate?
2. What is our total recognised revenue by product category?
3. What is the average order value for high-value customers compared with
   low-value customers?
4. How many products need planner review, and which categories are they in?
5. What is our cancellation rate, and does it differ by customer segment?
6. Which product categories have the best average product rating?
7. **Compare total order value with total recognised revenue by month.**

**Question 7 is the one to sit with.** The two numbers differ by about a
quarter, and the gap is the 192 cancelled orders. The agent gets that right
only because the Semantic View says so in a comment. Nothing about the raw data
would have told it.

**Expected result:** answers with the SQL the agent generated shown alongside.
Read the SQL. It is querying your semantic view, not guessing at table names.

### 7.2 dbt Semantic Layer, via the dbt MCP Server (guided)

The instructor will walk through this rather than everyone doing it live, and
there is an honest reason why.

The dbt MCP Server exposes your MetricFlow metrics as tools an AI agent can
call, so the agent asks dbt for `total_recognised_revenue` rather than writing
its own SQL against a table. Registering that server directly inside Snowflake
Intelligence **does not currently work**: Snowflake's external MCP connectors
require OAuth with a client secret, and dbt's remote MCP server issues public
clients using PKCE. Two products, two reasonable choices, one gap.

What does work today, and is worth twenty minutes of your own time afterwards,
is connecting the dbt MCP Server to an MCP client that supports it. Full
instructions, with the exact configuration:
[dbt-mcp-on-snowflake-ai.md](dbt-mcp-on-snowflake-ai.md).

**The thing to take away:** when the agent answers through the semantic layer,
it is constrained to metrics somebody defined and reviewed. When it writes its
own SQL, it is not. That difference is the entire argument for a governed
semantic layer, and it does not depend on which of the two you pick.

---

## Section 8: ship it (10 min)

### 8.1 A production job

In the dbt platform, create a job:

- Command: `dbt build`
- **Enable "generate docs on run"**
- Target the production environment

Run it. **Expected result:** green, and a docs site with your DAG.

### 8.2 Run it again and watch dbt State

Trigger the same job a second time without changing anything.

**Expected result:** the second run is substantially shorter, because dbt State
compares against the previous run and skips models whose inputs have not
changed.

That is the whole idea, and it is worth a moment. On a project this size it
saves seconds. On a project with 2,000 models and an hourly schedule, it is the
difference between a warehouse bill you can defend and one you cannot. You are
not paying to rebuild things that did not change.

### 8.3 Open a pull request

Commit your changes in dbt Studio and open a pull request against your fork.
**Do not merge it.**

The point is not shipping. It is that everything you did today (the model
changes, the contract update, the new metric) arrives as a reviewable diff.
Including the contract change, which is exactly the kind of thing you want a
second pair of eyes on.

---

## Section 9: what you built (5 min)

Raw PostgreSQL to a governed, AI-queryable semantic layer in under two hours:

- A Fivetran connector landing real rows in Snowflake
- A typed, tested staging layer
- Two contracted marts, plus a data-quality scorecard that found three real
  problems in the data
- Four bugs diagnosed and fixed by an agent you reviewed
- The same metrics defined two ways, and a clear view of when to use each
- Natural-language answers grounded in definitions somebody owns
- A production job, dbt State, and a reviewable pull request

**The thing worth remembering:** `order_total` and `recognised_revenue` are not
the same number, and nothing in the raw data tells you which one means revenue.
Somebody has to decide, write it down, and put it somewhere the AI can read.
That is what the last two hours were actually about.

### Next

- Read `projects/cpg/README.md` for the model-by-model tour
- Try the energy or financial services track against the instructor schema
- Add your own industry: [adding-an-industry.md](adding-an-industry.md)
