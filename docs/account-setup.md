# Account setup

**Time: 10 minutes, done in the first block of the lab.**

You need three accounts. All three are created on the day, and all three have a
fallback if provisioning does not work. Read the fallback column before you
start panicking about a missing email.

---

## Placeholders the instructor fills in

Everything in `{{DOUBLE_BRACES}}` is supplied on the day, on the lab
credentials card. None of it is in this repo, deliberately: the repo is public
and gets forked.

| Placeholder | What it is |
|---|---|
| `{{FIVETRAN_WORKSHOP_URL}}` | Fivetran workshop signup or invite acceptance URL |
| `{{DBT_WORKSHOP_URL}}` | dbt platform workshop signup URL |
| `{{LAB_CREDENTIALS_URL}}` | The credentials card, holding everything below |
| `{{PASSCODE}}` | Passcode for the credentials card |
| `{{POSTGRES_HOST}}` | Host of the source PostgreSQL database |
| `{{POSTGRES_USER}}` | Username for the source PostgreSQL database |
| `{{POSTGRES_PASSWORD}}` | Password for the source PostgreSQL user |
| `{{SNOWFLAKE_ACCOUNT}}` | Snowflake account identifier for the dbt connection |

---

## 1. Fivetran

| | |
|---|---|
| **How** | Accept the emailed invite, or go to `{{FIVETRAN_WORKSHOP_URL}}` |
| **What you get** | A seat in the shared workshop destination group, with the Snowflake destination already configured. You create connectors; you do not create destinations |
| **Time to provision** | Immediate on accepting the invite. 2 minutes to set a password and sign in |
| **You will need** | The source database password from the credentials card |

**Fallback:** skip Fivetran entirely. Leave `source_schema` in your track's
`dbt_project.yml` pointing at the instructor schema. You lose the experience of
watching your own rows land, and nothing else. Every subsequent step is
identical.

This is a real fallback, not a consolation prize. If your invite has not
arrived by 0:15, take it and move on.

Full walkthrough: [../fivetran/connector-setup.md](../fivetran/connector-setup.md).

---

## 2. dbt platform

| | |
|---|---|
| **How** | `{{DBT_WORKSHOP_URL}}`, or a standard trial at `getdbt.com` |
| **What you get** | A developer seat with dbt Studio, dbt Wizard, job scheduling and dbt State. Enough for everything in this lab |
| **Time to provision** | 3 to 5 minutes including email verification |
| **You will need** | Your forked repo URL, and Snowflake connection details from the credentials card |

**What to set up, in order:**

1. Create the account and verify your email.
2. **Connect Snowflake.** Account identifier `{{SNOWFLAKE_ACCOUNT}}`, database
   `HOL_SNOWFLAKE_INDUSTRY`, warehouse `HOL_DBT_WH`. Credentials are on the
   card.
3. **Connect your fork.** Not the original repo, your fork, or you will not be
   able to commit.
4. **Set the project subdirectory** to your track: `projects/cpg`,
   `projects/energy` or `projects/financial_services`. This is the step people
   miss, and the symptom is dbt reporting that it cannot find
   `dbt_project.yml`.

**Fallback:** the instructor has a shared account with pre-created developer
seats. Ask. There may also be a pre-configured workstation at the front of the
room.

---

## 3. Snowflake

| | |
|---|---|
| **How** | Usually supplied by the instructor. If you are creating your own, `signup.snowflake.com` |
| **What you get** | Read access to the lab database, and access to Snowflake Intelligence at `ai.snowflake.com` |
| **Time to provision** | Instant if supplied. 5 to 10 minutes for a self-service trial, plus email verification |

**If you are creating your own trial, pick your region deliberately.** Cortex
models are not available everywhere, and a trial that lands in the wrong region
cannot run the consumption section of the lab. Ask the instructor which region
to choose before you click.

**Fallback:** use the shared lab Snowflake account from the credentials card.
For the consumption section this is genuinely the better option anyway, because
the agents are already built there.

---

## Quick check before you start

| | Check | If not |
|---|---|---|
| [ ] | Forked the repo to your own GitHub account | Fork it now. Do not clone the original |
| [ ] | Picked a track | Consumer packaged goods if you are unsure |
| [ ] | Signed in to Fivetran | Skip it, use the instructor schema |
| [ ] | dbt platform connected to Snowflake **and** your fork | Ask. This one is worth stopping for |
| [ ] | Project subdirectory set to your track folder | Fix it now, nothing works without it |
| [ ] | Can sign in to Snowsight | Use the shared account |

The only one worth blocking on is the dbt platform connection. Everything else
has a fallback that costs you nothing.

---

## Common problems

**"dbt cannot find dbt_project.yml".**
The project subdirectory is not set, or is set to the repo root. It needs to be
`projects/<your track>`.

**"Object does not exist" when dbt reads a source.**
Either `source_schema` does not match what Fivetran actually created, or the
Snowflake grants are missing. Check the schema name first: it should be
`<firstname>_<lastname>_<schema>`, all lowercase. If it looks right, set it
back to the instructor schema and tell the facilitator, because a grants
problem affects everyone.

**Snowflake connection test fails in the dbt platform.**
Check the account identifier format. It is not the URL. If the account uses
key-pair authentication, you need the private key, not a password, and it must
be pasted including the `-----BEGIN PRIVATE KEY-----` and
`-----END PRIVATE KEY-----` lines.

**Cortex or Snowflake Intelligence is not available.**
Region problem, almost certainly, if you created your own trial. Switch to the
shared lab account.

**My Fivetran invite never arrived.**
Check spam, then stop looking. Use the instructor schema.
