# Facilitator guide

Everything you need to run this in a room of about 30 people creating accounts
on the day.

Companion documents: [agenda.md](agenda.md) for timings,
[answer-key.md](answer-key.md) for the seeded bugs, and
[../snowflake/GOTCHAS.md](../snowflake/GOTCHAS.md) for the Snowflake team.

---

## The one thing to internalise

**The instructor fallback schemas are the lab.** Every design decision in this
repo assumes that on the day, some Fivetran accounts will not arrive, some
syncs will be slow, and at least one person will typo their schema name.

If `hicham_bab_consumer_packaged_goods`, `hicham_bab_energy` and
`hicham_bab_financial_services` are populated and readable **as the dbt role**,
none of that matters and everybody finishes. If they are not, a slow sync ends
somebody's lab.

Verify them yourself, as the dbt role, not as ACCOUNTADMIN. ACCOUNTADMIN can
see everything and will cheerfully tell you the lab is fine.

Say the fallback out loud in the first five minutes, not at 1:00 when someone
is already stuck.

---

## Pre-flight

### Two weeks before

- [ ] Snowflake team has [../snowflake/GOTCHAS.md](../snowflake/GOTCHAS.md) and
      [../snowflake/reference_setup.sql](../snowflake/reference_setup.sql)
- [ ] Confirm who owns the Snowflake account and who will be in the room from
      that team
- [ ] Fivetran workshop account requested, with enough seats for the headcount
      plus five
- [ ] dbt platform workshop accounts requested
- [ ] Confirm the Snowflake account region supports the Cortex models, or that
      `CORTEX_ENABLED_CROSS_REGION` will be set

### One week before

- [ ] `HOL_SNOWFLAKE_INDUSTRY` exists, warehouses exist, roles and grants
      applied
- [ ] `FIVETRAN_SVC` and `DBT_SVC` are `TYPE = SERVICE` with key-pair auth, and
      both connections test green. **Password-only service users are being
      blocked right now, between August and October 2026.** Gotcha 1
- [ ] Future grants set at database level **and** grants on existing objects.
      Gotcha 2
- [ ] Instructor fallback schemas populated via Fivetran with prefix
      `hicham_bab`, all three source schemas selected
- [ ] Identifier casing confirmed, and `quoting` in all three
      `dbt_project.yml` files matches. Gotcha 3

### Three days before: the dry run

**Do not skip this.** `dbt deps` and `dbt parse` have been run against all three
tracks and all three pass cleanly on dbt-fusion 2.0.0-preview.200. `dbt compile`
and `dbt build` have **not** run, because there was no warehouse to run them
against. See `BUILD-NOTES.md` section 4.

For each of the three tracks, as an attendee would:

- [ ] `dbt deps`
- [ ] `dbt parse` → **`Finished 'parse' successfully`**, no errors, no warnings
- [ ] `dbt seed` (energy only)
- [ ] `dbt build --select staging` → **green**. Record the model and test counts
      so you can put real numbers in front of the room
- [ ] `dbt build` → fails with exactly the bugs in [answer-key.md](answer-key.md),
      and no others
- [ ] Apply every fix from the answer key → `dbt build` fully green
- [ ] Time the full build and note it

If anything fails that is not in the answer key, fix it in the repo before the
day and tell the author.

#### The one check that actually matters: when do the bugs surface?

Fusion does column-aware static analysis when it can reach the catalog. Parsed
without a warehouse connection, it did **not** flag the wrong-column-name bugs
or the missing `group by`. With a live connection it might raise some of them at
**parse** instead of at build, and a parse error fails the whole project,
including `dbt build --select staging`. That would break checkpoint 1 for
everyone, which is the one hard gate in the lab.

This is already proven to be a real failure mode: `HOL_BUG_CPG_02` used to be a
typo'd `ref()`, and on Fusion that is a parse-time error that took checkpoint 1
down. It was changed to a column-name error for exactly this reason.

**Run this check, per track, with the real Snowflake connection:**

```bash
dbt parse          # must succeed
dbt build --select staging   # must be green
```

- **Both clean:** you are fine. The bugs surface at build, as designed.
- **`dbt parse` errors:** note which bug IDs appear. Those bugs break
  checkpoint 1 and must be swapped before the day.

**If a bug does surface at parse**, swap it for one of these, which cannot be
caught statically because they depend on data values or on test results:

| Broken bug | Safe replacement |
|---|---|
| A wrong column name | A `cast()` of a text column that holds non-numeric values, like `HOL_BUG_FS_01` |
| A missing `group by` | An `accepted_values` test missing a real value, like `HOL_BUG_ENERGY_03` |
| A contract mismatch | A `dbt_utils.accepted_range` with an unreachable threshold, like `HOL_BUG_CPG_03` |

Tell the author either way, so the repo gets fixed rather than just your copy.

### Two days before

- [ ] dbt job run in production so the Semantic Views exist
- [ ] Semantic View grants applied **after** that job. Gotcha 8
- [ ] Three Cortex Agents created per
      [../snowflake/cortex_semantic/agents_setup.md](../snowflake/cortex_semantic/agents_setup.md),
      with the agent instructions pasted in. Those instructions are not
      optional: they are what stops the CPG agent reporting the wrong revenue
      and the energy agent returning empty answers for "this year"
- [ ] Ask one question per track in Snowflake Intelligence, **signed in as a
      user whose only role is `HOL_ATTENDEE`**

### Day of, before doors open

- [ ] Both warehouses resumed and warm
- [ ] Fallback schemas readable as the dbt role: run the three `count(*)`
      queries from `reference_setup.sql` section 11
- [ ] Lab credentials card published, all `{{PLACEHOLDER}}` values filled in
- [ ] `{{POSTGRES_PASSWORD}}` on the card and **not** committed to the repo
- [ ] Projector shows the repo README, and the track picker table is legible
      from the back of the room

---

## Room logistics for three tracks at once

### Steering people

Ask two questions as they arrive, not one:

1. **"How comfortable are you with SQL joins?"**
2. **"What industry are you in?"**

| Answer | Send them to |
|---|---|
| New to dbt, wants a clean run | **Consumer packaged goods.** One source table, two marts, nothing surprising |
| Comfortable, likes a puzzle | **Energy.** The unpivot and the duplicate-feed discovery are the most fun in the lab |
| Confident with joins, wants the hardest | **Financial services.** Five-table star, real PII |
| Works in a bank or insurer | **Financial services**, if they are comfortable. The narrative sells itself |
| Retail, manufacturing, consumer | **Consumer packaged goods** |
| Utilities, oil and gas, industrials | **Energy** |
| Genuinely no preference | **Consumer packaged goods.** It is the safest |

Expect roughly 40 / 30 / 30. If financial services goes above about a third of
the room, spend more of your floor time there: it has the most places to get
stuck.

### Supporting three tracks

**Do not try to track three DAGs in your head.** Work from the symptom.

| Attendee says | It is almost always |
|---|---|
| "It can't find dbt_project.yml" | Project subdirectory not set to `projects/<track>` |
| "Object does not exist" | `source_schema` typo, or the sync has not finished |
| "invalid identifier" on a staging column | They are past checkpoint 1 and hit bug 01 |
| "Contract failed" | Bug 04 in CPG or energy, bug 02 in financial services |
| "My test failed but the data looks fine" | Bug 03. That is the lesson, let them sit with it |
| "The agent gave a weird number" | Agent instructions not saved on the agent |

**Timebox any individual to three minutes.** Then put them on the instructor
schema and move on. One person's Fivetran connector is not worth ten people's
attention.

### The two moments to pull the whole room together

**At about 1:05, energy bug 02.** Adding `maintenance_status` to the `group by`
makes the error disappear and silently changes the grain. Ask who fixed it that
way. Usually a third of them.

**At about 1:10, financial services bug 02.** The contract fails because a PII
column is declared but not produced. One fix removes it from the contract; the
other adds employer names back into a table an AI agent can read. Both compile.
Ask the room which one they would have accepted at 4pm on a Friday.

Those two moments are the argument for reviewing agent output, and they land
far better as a live show of hands than as a slide.

---

## Failure playbook

| Symptom | First response | If that fails |
|---|---|---|
| Fivetran invite never arrived | Instructor schema, carry on | Shared account from the credentials card |
| Sync still running at 0:40 | Instructor schema, check back later | Leave it. Nothing downstream needs it |
| `dbt build --select staging` red | Revert `source_schema` to `hicham_bab_*` | Check the project subdirectory |
| "Object does not exist" across several people at once | **Stop. This is a grants problem, not theirs.** Gotcha 2 | Everyone on the instructor schema, escalate to the Snowflake team |
| "invalid identifier" on a source column across several people | Identifier casing. Gotcha 3 | Everyone on the instructor schema. This one is not fixable in the room |
| dbt platform will not connect to Snowflake | Check account identifier format, then key vs password | Shared dbt account |
| Cortex agent returns nothing, no error | Missing grants on the tables under the Semantic View. Gotcha 8 | Demo on the projector from your own session |
| Cortex agent worked yesterday, not today | The dbt job re-created the Semantic View and dropped its grants. Re-run them. Gotcha 8 | Same |
| Cortex not available at all | Region. `CORTEX_ENABLED_CROSS_REGION`. Gotcha 7 | Shared lab Snowflake account |
| Whole room behind at 1:15 | Compress section 7 to a projector demo, section 8 to 5 minutes | Drop the pull request to homework |
| Someone finished at 1:10 | Stretch prompts at the end of [answer-key.md](answer-key.md) | Have them help a neighbour |

---

## Timing table

Matches [agenda.md](agenda.md). Print this.

| Clock | Section | Min | Gate |
|---|---|---|---|
| 0:00 | Welcome, fork, pick, accounts | 10 | Everyone has forked and chosen |
| 0:10 | Fivetran connector, start sync | 15 | Sync started, or fallback taken |
| 0:25 | dbt setup, sources, staging | 15 | **Checkpoint 1 green** |
| 0:40 | dbt Studio and Fusion tour | 10 | |
| 0:50 | dbt Wizard, four bugs, one model | 25 | At least two bugs fixed |
| 1:15 | Semantic layer, two ways | 12 | Both files opened side by side |
| 1:27 | Ask your data | 18 | One question answered |
| 1:45 | Production job, dbt State, PR | 10 | |
| 1:55 | Wrap | 5 | |
| 2:00 | End | | |

**The only hard gate is checkpoint 1 at 0:50.** Everything after it degrades
gracefully. Nothing before it does.

---

## Things to say out loud

**At 0:05, the fallback.** *"If anything goes wrong with your own data, change
one line and you are on my copy. Nobody will know and you will not miss
anything."* Repeat it at 0:25.

**At 0:20, on `_fivetran_synced`.** It is not in the source. Fivetran added it.
It is how you answer "when did this row last change" without asking anyone.

**At 0:45, on Fusion.** The error appeared before anything ran. That is the
whole pitch: the feedback loop is at typing speed, not at warehouse speed.

**At 0:50, before they run `dbt build`.** *"This is going to fail. Four things
are broken on purpose. Do not fix them by hand, and do not let the agent fix
them without reading the diff."*

**At 1:20, on the two semantic layers.** The question is not which is better.
It is where the definition of revenue should live and who else needs to read it.

**At 1:35, financial services.** Have somebody ask the agent for a customer's
social security number. It cannot answer, because the column does not exist.
That is the difference between a policy and a control, and it demonstrates
better than any slide.

**At 1:50, on dbt State.** On a project this size it saves seconds. On 2,000
models running hourly it is the difference between a warehouse bill you can
defend and one you cannot.

---

## Known gaps, so you are not caught out

**The dbt MCP Server cannot currently be registered inside Snowflake
Intelligence.** Snowflake's external MCP connectors require OAuth with a client
secret; dbt's remote MCP issues public clients using PKCE. Separately,
Snowflake has no documented way to send the `x-dbt-prod-environment-id` header
dbt requires.

Section 7 handles this honestly: Cortex Analyst against the Snowflake Semantic
View is fully hands-on, and the dbt MCP half is a guided walkthrough with a
take-home that genuinely works. Full detail and citations in
[dbt-mcp-on-snowflake-ai.md](dbt-mcp-on-snowflake-ai.md).

**Do not gloss over this if someone asks.** Explaining precisely why two
products do not yet interoperate is more credible than pretending the gap is
not there, and it is the kind of thing the room will remember you for.

**Re-check it before every delivery.** Both products are moving fast.

**No live `dbt build` has been run against a warehouse for this repo.** The
dry run three days out is how that gets closed. See `BUILD-NOTES.md` section 4.

---

## After the lab

- [ ] Suspend both warehouses
- [ ] Consider dropping attendee schemas: 30 people times one schema each
- [ ] Note anything that broke, and open an issue on the repo
- [ ] If the dbt MCP and Snowflake AI gap has closed, update
      [dbt-mcp-on-snowflake-ai.md](dbt-mcp-on-snowflake-ai.md), the three
      attendee guides and this file
