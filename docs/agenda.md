# Run of show: two hours

Hard stop at 120 minutes. Everything below is timeboxed, and every attendee
guide carries the same minute budgets in its section headers so people can tell
at a glance whether they are ahead or behind.

---

## The schedule

| Clock | Section | Min | Who is doing what |
|---|---|---|---|
| 0:00 | Welcome, fork the repo, pick your industry | 8 | Instructor leads, attendees fork and choose |
| 0:08 | Fivetran connector, start the sync | 15 | Hands-on. Sync runs in the background from here |
| 0:23 | dbt platform setup, sources and staging, **first green build** | 15 | Hands-on. `dbt/setup.md` then guide section 3 |
| 0:38 | dbt Studio and Fusion tour on the data-quality view | 8 | Instructor demos, attendees follow along |
| 0:46 | **dbt Wizard: fix four broken things, then build one from intent** | 25 | Hands-on. The centre of the lab |
| 1:11 | Semantic layer, defined two ways | 10 | Hands-on |
| 1:21 | Production job, docs generation, dbt State | 8 | Hands-on |
| 1:29 | **dbt Catalog: the metadata the agent will use** | 8 | Instructor demos, attendees follow in their own Catalog |
| 1:37 | Ask your data in plain English | 18 | Hands-on, instructor-led for the MCP half |
| 1:55 | Wrap, pull request, next steps | 5 | Instructor |
| 2:00 | End | | |

Hands-on time: 89 minutes. The remaining 31 is welcome, the two instructor-led
demos (Fusion and Catalog) and the wrap.

**Note the ordering.** The production job now runs *before* the Catalog tour,
and Catalog runs *before* the AI section. That is deliberate: Catalog needs a
successful production job to have anything in it, and the whole point of
Catalog here is to show attendees what metadata the agent is about to consume.
Build it, publish it, look at it, then let an AI use it.

---

## Where the slack actually is

There is no dedicated buffer block, because in a two-hour lab a buffer block is
the first thing that gets eaten. Instead there are four places to take time
back, in the order you should take it.

**1. The Fivetran sync overlaps the dbt setup.** Attendees start the sync at
0:10 and immediately move to dbt while it runs. Nobody watches a progress bar.
If the sync is slow, they simply never switch off the instructor schema and
lose nothing.

**2. Section 9, the dbt MCP half, is the designed compression point.** If you
are behind at 1:27, run the Snowflake Semantic View half fully hands-on and
deliver the dbt MCP Server half as a walkthrough on the projector. Saves 8
minutes and costs nothing, because the MCP path is currently a read-through
anyway (see below).

**3. Section 7 can drop to 5 minutes.** Show the dbt State second run on the
projector rather than having 30 people trigger jobs simultaneously. But **the
job itself must run for every attendee**, or their Catalog is empty in the next
section.

**4. Section 6 can drop to 8 minutes.** The two semantic definitions are
already written in the repo. If time is short, read them side by side and skip
building a new metric.

**5. Section 8, dbt Catalog, can drop to 4 minutes.** Show lineage and one
model's Columns tab on the projector and move on. Do not cut it entirely: it is
what makes the AI section land as engineering rather than as a magic trick.

**Do not compress section 5.** It is the reason people came.

---

## What each section has to land

### 0:00 Welcome, fork, pick (8 min)

Get three things done: everyone has forked the repo, everyone has chosen a
track, and everyone knows the fallback exists.

Say the fallback out loud now, not at 1:00 when someone is stuck: *"if anything
goes wrong with your own data, change one line in `dbt_project.yml` and you are
back on the instructor's copy. Nobody will know and you will not miss anything."*

Steer nervous attendees to consumer packaged goods or energy, confident ones to
financial services. Nobody is scoring this.

### 0:08 Fivetran (15 min)

The point is not "configuring a connector is hard". It is that it takes four
minutes and then raw tables exist in Snowflake. The `_fivetran_synced` column
is worth thirty seconds: it is not in the source, Fivetran added it, and it is
how you answer "when did this row last change".

Attendees move on to dbt while the sync runs. Financial services is the biggest
at ~198,000 rows and can take 8 minutes.

### 0:23 dbt platform setup and first green build (15 min)

Attendees work through [../dbt/setup.md](../dbt/setup.md), then guide section 3.
Connect the fork, **set the project subdirectory**, create a dev and a
production environment, set `source_schema`, `dbt deps`,
`dbt build --select staging`.

**This is checkpoint 1 and it must be green for everyone.** Nothing in staging
is booby-trapped.

Two things to police here, because both bite later. The **project
subdirectory** must be `projects/<track>`, or nothing works at all. The
**production environment** must exist, or dbt Catalog is empty at 1:29.

If someone is red here, it is their `source_schema` or their sync. One line,
change it back, move on.

### 0:38 Fusion tour (8 min)

Instructor drives, attendees follow in their own editor. Use the
`vw_*_data_quality` view in each track: it is a chain of small CTEs chosen for
exactly this.

Three beats: hover a column and see the type Fusion inferred without running
anything; break a `ref()` and watch the error appear before you run; preview a
single CTE in the middle of the model.

### 0:46 dbt Wizard (25 min), the centre of the lab

Run `dbt build`. It fails. Four things in every track are deliberately broken.

Attendees prompt dbt Wizard to diagnose and fix each one, reviewing and
accepting every change rather than letting it apply blind. The review step is
the teaching point: the agent writes, the human stays accountable.

Then one model built from intent, so it is not purely a repair exercise.

Budget roughly 15 minutes on the bugs and 10 on building something new. If the
room is fast, the answer key has stretch prompts.

### 1:11 Semantic layer, two ways (10 min)

The crux. The same metrics exist in a Snowflake Semantic View and in dbt
Semantic Layer specs. Open both files side by side.

The question to leave them with is not "which is better" but "where should the
definition of revenue live, and who else needs to read it".

### 1:21 Ship it to production (8 min)

A production job: `dbt build`, **"generate docs on run" enabled**, targeting the
production environment. Run it twice; the second run skips unchanged models via
dbt State.

Two reasons this moved earlier in the day. dbt State is a better story once
people have actually built something, and Catalog in the next section is empty
without a successful production run behind it.

**Police the "generate docs on run" checkbox.** Without it the Catalog Columns
tab is blank, and the Columns tab is the whole point of the next section.

### 1:29 dbt Catalog (8 min)

The bridge between what they built and what the AI is about to consume.

The line to say out loud: **dbt Catalog and the dbt MCP Server read the same
metadata, through the same Discovery API.** Catalog renders it for a human, the
MCP Server hands it to an agent. So this is not a documentation tour, it is a
preview of the agent's context window.

Three beats: the lineage graph with lenses, a mart's Columns tab, and the
Details section showing **contracted status** on the marts they contracted in
section 5.

Then the payoff. Have them read one good column description out loud, and then
find a thin one. Good AI answers come from descriptions, tests, contracts and
metric definitions, which means they come from the pull request, not the prompt.

Note that column-level lineage and model performance are Enterprise+ only, so
trial accounts may not show them. Everything else works on all plans.

### 1:37 Ask your data (18 min)

Cortex Analyst against the Snowflake Semantic View: fully hands-on, works
today. Sample questions are in
[../snowflake/cortex_semantic/agents_setup.md](../snowflake/cortex_semantic/agents_setup.md).

This lands harder straight after Catalog, because they have just seen the
metadata the agent is using.

The dbt MCP Server half is currently a guided read-through rather than
hands-on, because the direct registration into Snowflake Intelligence does not
work yet. The reason is specific and worth explaining rather than glossing:
Snowflake's external MCP connectors require OAuth with a client secret and
dbt's remote MCP issues public clients using PKCE. See
[dbt-mcp-on-snowflake-ai.md](dbt-mcp-on-snowflake-ai.md), which also gives a
path that does work if anyone wants to try it after.

Financial services attendees should ask the agent for a customer's social
security number. It cannot answer, because the column was never selected. That
is the governance beat and it lands better as a demo than as a bullet.

### 1:55 Wrap and pull request (5 min)

Commit and open a pull request. Do not merge; the point is that the change is
reviewable, not that it ships.

Then what they built, what to read next, and how to get the data into their own
account.

---

## If you are running behind

| At this clock | You should be at | If you are not |
|---|---|---|
| 0:23 | Sync started, moving to dbt | Fine. Put them on the instructor schema and continue |
| 0:46 | Everyone green on checkpoint 1 | Stop and fix stragglers now. Everything after depends on it |
| 1:11 | At least two bugs fixed | Move on anyway. Two is enough to make the point |
| 1:29 | Production job green for everyone | Demo Catalog from your own account instead |
| 1:37 | Catalog toured | Compress the MCP half to a projector walkthrough |

Two hard gates: checkpoint 1 at 0:46, and a green production job at 1:29,
because an empty Catalog makes the next section pointless. Everything else
degrades gracefully.
