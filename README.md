# Fivetran, Snowflake and dbt: a two-hour hands-on lab

Build the full modern data stack loop on your own data, in your own accounts,
in two hours.

```
Fivetran          Snowflake       dbt platform        semantic layer         Snowflake
(ingest)     ->   (store)    ->   (transform     ->   (define meaning)  ->   Intelligence
                                   and govern)                                (ask in English)
```

You will land raw data with a Fivetran connector, model it in dbt Studio with
dbt Wizard doing the heavy lifting, define the same metrics two different ways,
and then ask questions of your own data in plain English.

---

## Start here: three steps, about a minute

### 1. Fork this repo

Click **Fork** at the top right of
`github.com/hicham-bab/snowflake-fivetran-dbt-hol`. Work in your fork, not in
the original. You will connect the fork to dbt Studio in a few minutes.

### 2. Pick your industry

You only do one. Pick the one closest to your day job, or the one that sounds
most interesting. All three take the same time.

| Track | Folder | The story | Pick it if |
|---|---|---|---|
| **Consumer packaged goods** | [`projects/cpg`](projects/cpg) | Order and product performance: order value, customer lifetime value, stockout and overstock risk, price optimisation | You want the cleanest run. One source table, two marts, no surprises |
| **Energy** | [`projects/energy`](projects/energy) | Commodity price history across 23 traded commodities, plus equipment reliability and maintenance economics | You like a reshaping problem. Wide-to-long unpivot, and two source feeds that are secretly the same data |
| **Financial services** | [`projects/financial_services`](projects/financial_services) | Credit risk across 1,000 customers and 20 lending institutions: risk scores, fraud probability, exposure, approvals | You are comfortable with joins and want the hardest one. A five-table star, and real personal data to govern |

New to dbt? Take **consumer packaged goods** or **energy**. Both finish
comfortably. Financial services is the same length but the data works harder to
trip you up.

> ### Whichever track you pick, you must tell the dbt platform about it
>
> This repo holds three separate dbt projects. The dbt platform does not know
> which one is yours until you say so.
>
> When you set up your dbt platform project, there is a field called
> **Project subdirectory**. Type your track's folder path into it:
>
> | If you picked | Type this into **Project subdirectory** |
> |---|---|
> | Consumer packaged goods | `projects/cpg` |
> | Energy | `projects/energy` |
> | Financial services | `projects/financial_services` |
>
> Leave it blank and dbt looks in the repo root, finds no `dbt_project.yml`,
> and nothing works. This is the single most common setup mistake in the lab.
>
> Where to find it: **Account settings → Projects → your project → Edit**,
> under the repository settings. You can change it later if you pick the wrong
> one.

### 3. Set up your three tools

One folder per tool. Do them in this order; the dbt one is the only one without
a fallback.

| Tool | Setup page | Time |
|---|---|---|
| Fivetran | [fivetran/connector-setup.md](fivetran/connector-setup.md) | 15 min, mostly waiting |
| **dbt platform** | **[dbt/setup.md](dbt/setup.md)** | **15 min. Cannot be skipped** |
| Snowflake | [docs/account-setup.md](docs/account-setup.md) | Usually supplied by the instructor |

### 4. Open your guide and go

| Track | Your guide |
|---|---|
| Consumer packaged goods | [docs/attendee-guide-cpg.md](docs/attendee-guide-cpg.md) |
| Energy | [docs/attendee-guide-energy.md](docs/attendee-guide-energy.md) |
| Financial services | [docs/attendee-guide-financial-services.md](docs/attendee-guide-financial-services.md) |

Every section in those guides carries a minute budget. If you fall behind,
each one also tells you how to skip ahead without breaking anything.

---

## What you will actually do

| | What | Minutes |
|---|---|---|
| 1 | Fork the repo, pick your industry, get your accounts | 10 |
| 2 | Build a Fivetran connector and watch raw tables land in Snowflake | 20 |
| 3 | Point dbt at your data, tour dbt Studio and Fusion | 20 |
| 4 | Build with dbt Wizard, and fix four deliberately broken things | 25 |
| 5 | Define your metrics twice: Snowflake Semantic View and dbt Semantic Layer | 10 |
| 6 | Ship it: a production job with docs, and dbt State | 8 |
| 7 | Tour dbt Catalog: see exactly what metadata an AI agent will use | 8 |
| 8 | Ask questions of your data in plain English | 18 |
| 9 | Wrap up and open a pull request | 5 |

Full run of show: [docs/agenda.md](docs/agenda.md).

---

## The one thing that will save you

**Every step has a fallback.** If your Fivetran sync is slow, broken, or your
account never showed up, you are not stuck. Open your track's
`dbt_project.yml`, find this line, and leave it exactly as it is:

```yaml
vars:
  source_schema: 'hicham_bab_consumer_packaged_goods'   # or _energy, or _financial_services
```

That points at the instructor's copy of the same data. Everything downstream
works identically. You can switch to your own schema later, or never. Nobody
will know and the lab still teaches the same thing.

---

## Two things this lab is really about

**dbt Wizard is an agent, not autocomplete.** You will not spend two hours
typing SQL that is already written. You will describe what you want, review
what the agent produces, and accept or push back. The review step is the point:
the agent writes, you stay accountable. Four things in your track are
deliberately broken, and you will fix them by talking to the agent rather than
by reading the answer key.

**Good AI answers come from the pull request, not the prompt.** Before you ask
an AI anything, you will tour dbt Catalog and see the exact metadata it is
about to read: your descriptions, your data types, your test results, your
contracts. Catalog and the dbt MCP Server pull from the same Discovery API, so
what you see there is what the agent gets. It reframes documentation from
hygiene into the thing that decides whether the answer is right.

**Meaning gets defined twice, on purpose.** The same metrics exist in two
places: a Snowflake Semantic View, native to Snowflake and read by Cortex
Analyst, and dbt Semantic Layer specs, living in this repo and read through the
dbt MCP Server. They are not redundant, they are two answers to "where should
the definition of revenue live". Your track has both, side by side, and the
guides are explicit about when you would reach for each.

---

## Repo map

```
├── README.md                    you are here
├── BUILD-NOTES.md               design decisions and what the real data does
├── docs/
│   ├── agenda.md                the two-hour run of show
│   ├── account-setup.md         Fivetran, dbt platform and Snowflake signup, and fallbacks
│   ├── attendee-guide-*.md      one step-by-step guide per track
│   ├── dbt-mcp-on-snowflake-ai.md   wiring the dbt MCP Server into an AI client
│   ├── facilitator-guide.md     instructor runbook
│   ├── answer-key.md            facilitator only: every seeded bug and its fix
│   └── adding-an-industry.md    how to add a fourth track
├── fivetran/                    SETUP: ingest
│   └── connector-setup.md       PostgreSQL to Snowflake, step by step
├── dbt/                         SETUP: transform and govern
│   ├── setup.md                 dbt platform: connection, repo, subdirectory,
│   │                            environments. The one you cannot skip
│   └── catalog-tour.md          dbt Catalog: the metadata an AI agent can see
├── snowflake/                   SETUP: store. Owned by the Snowflake team
│   ├── GOTCHAS.md               the integration traps that break Fivetran-to-dbt labs
│   ├── reference_setup.sql      minimal database, warehouse, roles and grants
│   └── cortex_semantic/         reference Semantic View DDL and agent setup
└── projects/
    ├── _template/               skeleton for adding a new industry
    ├── cpg/
    ├── energy/
    └── financial_services/
```

## Adding a fourth industry

The source database has 26 schemas; this lab uses three. Adding another is a
copy-paste-and-adapt job: see [docs/adding-an-industry.md](docs/adding-an-industry.md)
and start from [`projects/_template`](projects/_template).

## Running the lab yourself

Facilitators start at [docs/facilitator-guide.md](docs/facilitator-guide.md).
The Snowflake team starts at [snowflake/GOTCHAS.md](snowflake/GOTCHAS.md),
which is short, opinionated, and will save an afternoon.
