# Screenshots

Placeholder image references in the attendee guides point here. They are
intentional, not broken links: the guides are written to be usable before the
screenshots exist, with a prose description under every image so nothing is
lost if the picture is missing.

Drop the files in with these exact names and they light up.

## Needed

| File | What to capture |
|---|---|
| `dbt-01-project-subdirectory.png` | dbt platform project settings with **Project subdirectory** filled in as `projects/cpg`. Crop tight on the field and its label; this is the most-missed step in the lab |

## Nice to have

| File | What to capture |
|---|---|
| `fivetran-01-connector-setup.png` | The PostgreSQL connector form with the destination schema prefix visible |
| `fivetran-02-schema-selection.png` | Schema selection with one track's schema enabled and the rest blocked |
| `dbt-02-fusion-hover.png` | dbt Studio, hovering a column in `vw_*_data_quality` and showing the inferred type |
| `dbt-03-wizard-diff.png` | dbt Wizard proposing a fix, with the review and accept controls visible |
| `dbt-04-catalog-columns.png` | dbt Catalog, Columns tab of a mart, showing data types, descriptions and per-column test results |
| `dbt-05-catalog-contract.png` | dbt Catalog, Details section showing contracted status on a mart |
| `snowflake-01-cortex-answer.png` | Snowflake Intelligence answering a track question, with the generated SQL expanded |

## Conventions

- PNG, roughly 1600px wide, light mode
- Crop to the relevant panel, not the whole browser
- Redact account names, real emails and any host or account identifier before
  committing. This repository is public
- Keep the prose description under each image in the guides even after the
  screenshot lands. UIs move; prose survives longer, and it is what a
  screen-reader user gets
