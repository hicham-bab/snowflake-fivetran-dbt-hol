# Track template

Skeleton for a new industry track. Copy it, fill in every placeholder, delete
this file and replace it with a real per-track README.

```bash
cp -r projects/_template projects/<track_key>
```

Full walkthrough with the reasoning: [../../docs/adding-an-industry.md](../../docs/adding-an-industry.md).

---

## Find everything you still have to fill in

```bash
grep -rn "FILL ME\|<track_key>\|<TRACK\|<source_table>\|<column" projects/<track_key>/
```

When that returns nothing, you are done.

---

## Files to rename

The template uses generic names so nothing collides before you start. Rename
all six:

| From | To |
|---|---|
| `models/staging/_track__sources.yml` | `_<track_key>__sources.yml` |
| `models/staging/_track__models.yml` | `_<track_key>__models.yml` |
| `models/staging/stg_source_table.sql` | `stg_<source_table>.sql` |
| `models/intermediate/int_track_subject.sql` | `int_<track_key>_<subject>.sql` |
| `models/marts/track_mart.sql` | `<track_key>_<subject>.sql` |
| `models/marts/vw_track_data_quality.sql` | `vw_<track_key>_data_quality.sql` |
| `models/marts/sv_track_subject.sql` | `sv_<track_key>_<subject>.sql` |
| `models/marts/_track__marts.yml` | `_<track_key>__marts.yml` |
| `models/semantic/track.yml` | removed; see `models/semantic/README.md` |
| `tests/assert_something_meaningful.sql` | `assert_<what_it_checks>.sql` |

---

## What each folder is for

```
dbt_project.yml     the ONLY per-track config. Track identity and source
                    schema live in one vars block at the top
packages.yml        dbt_utils and Snowflake-Labs/dbt_semantic_view. Do not edit
models/staging/     one typed, renamed view per source table. No joins, no
                    logic. MUST be green at checkpoint 1
models/intermediate/ joins, reshapes, derived flags and banding. Where the
                    business decisions live
models/marts/       business-facing tables with enforced contracts, the
                    data-quality view, and the Snowflake Semantic View
models/semantic/    README only. Under the latest spec the semantic layer
                    lives in the marts YAML beside the contract. Top-level
                    cross-model metrics may still go here
seeds/              lookups. See the energy track's commodity_reference.csv
tests/              two or three singular tests guarding real invariants
macros/             empty, and should stay that way. A beginner has to be able
                    to read any model top to bottom without chasing an
                    abstraction
```

---

## The five rules that keep tracks interchangeable

**1. Staging is always green.** Never put a seeded bug in a staging model or a
staging test. Checkpoint 1 (`dbt build --select staging`) is the one hard gate
in the lab, and if it fails, the attendee's first experience is confusion
rather than a working pipeline.

**2. Cast every contracted column explicitly.** `cast(x as number(18,2))` in
the SQL and `data_type: number(18,2)` in the YAML. This is what makes enforced
contracts safe to ship without a live warehouse to test against.

**3. Verify every `accepted_values` list against the real data.** Do not write
one from the brief or from a guess. Query `select distinct` first. A wrong list
fails at checkpoint 1 and blocks the room.

**4. State the grain in every model header.** "Grain: one row per X." It is
what lets a reviewer, and dbt Wizard, tell a correct fix from a plausible one.
The energy `group by` bug depends entirely on this being written down.

**5. Never seed a parse-time bug.** Two kinds fail the whole project before
anything runs, taking checkpoint 1 with them: a malformed `semantic_model:` or
`metrics:` block, and an unresolvable `ref()`. Both are verified on Fusion, not
theoretical. Use a wrong column name, a bad threshold or a contract mismatch
instead.

---

## Seeding the four bugs

Every track ships four, marked `-- HOL_BUG_<TRACK>_<nn>`, then documented in
[../../docs/answer-key.md](../../docs/answer-key.md).

Spread them across independent DAG branches so one failure does not block
everything. A shape that works:

| ID | Layer | Kind |
|---|---|---|
| 01 | intermediate | wrong column name after a staging rename, or a bad cast |
| 02 | mart SQL | a wrong column name, or a missing `group by` column |
| 03 | mart test | a threshold or `accepted_values` list that is wrong |
| 04 | mart contract | a declared column the model does not produce |

**Include at least one bug with a wrong fix that compiles.** Those are where
"review the agent's diff" stops being advice and becomes a lesson. See
`ENERGY_02`, `FS_02` and `FS_04`.

---

## Before you call it done

- [ ] `grep -rn "FILL ME" projects/<track_key>/` returns nothing
- [ ] `dbt deps` then `dbt build --select staging` is green
- [ ] `dbt build` fails with exactly your four bugs and nothing else
- [ ] Applying the answer key makes `dbt build` fully green
- [ ] Full build takes under 60 seconds on an XS warehouse
- [ ] Attendee guide written, with the same section numbers and minute budgets
      as the other three
- [ ] Track added to the picker table in the top-level `README.md`
- [ ] Bugs added to `docs/answer-key.md`
- [ ] Sample questions and agent instructions added to
      `snowflake/cortex_semantic/agents_setup.md`
