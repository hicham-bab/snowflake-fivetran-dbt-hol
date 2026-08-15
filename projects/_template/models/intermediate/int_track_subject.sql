-- ---------------------------------------------------------------------------
-- RENAME THIS FILE to int_<track_key>_<subject>.sql
--
-- The intermediate layer is where business logic lives: joins, reshapes,
-- derived flags, banding. Staging renames and types; marts publish. This is
-- where decisions get made.
--
-- State the GRAIN in the header. Every model in this lab does, and it is what
-- lets a reviewer (or an agent) tell a correct fix from a plausible one.
--
-- Grain: one row per <...>.
-- ---------------------------------------------------------------------------

{{ config(materialized='view') }}

with <source_cte> as (

    select * from {{ ref('stg_<source_table>') }}

),

derived as (

    select
        <source_cte>.*,

        -- ---- derived: banding ------------------------------------------------
        -- Prefer thresholds the business actually uses over statistical
        -- quantiles. "The threshold the trading team uses in their weekly
        -- review" is a definition somebody owns; a tercile is not.
        case
            when <measure> >= <high_threshold> then '<High label>'
            when <measure> >= <mid_threshold> then '<Mid label>'
            else '<Low label>'
        end as <band_column>,

        -- ---- derived: flags ---------------------------------------------------
        case
            when <condition> then true
            else false
        end as is_<something>,

        -- ---- derived: safe division ---------------------------------------------
        -- nullif() on every denominator. A divide-by-zero takes the model down
        -- for everyone in the room.
        round(<numerator> / nullif(<denominator>, 0), 4) as <ratio_column>

    from <source_cte>

)

select * from derived
