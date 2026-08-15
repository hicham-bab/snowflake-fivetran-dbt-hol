-- ---------------------------------------------------------------------------
-- RENAME THIS FILE to <track_key>_<subject>.sql
--
-- Business-facing mart. This is what people query and what the semantic layer
-- sits on top of.
--
-- CONTRACT ENFORCED. dbt builds an empty table from the column list in the
-- marts YAML, compares it against what this model produces, and refuses to
-- build if they differ.
--
-- THE RULE THAT MAKES CONTRACTS SAFE: cast every column explicitly, to exactly
-- the type declared in the YAML. cast(x as number(18,2)) here and
-- data_type: number(18,2) there. Do that and a contract mismatch is impossible
-- unless somebody genuinely changed the shape.
--
-- Grain: one row per <...>.
-- ---------------------------------------------------------------------------

{{ config(materialized='table') }}

with <source_cte> as (

    select * from {{ ref('int_<track_key>_<subject>') }}

)

select

    -- ---- keys ---------------------------------------------------------------
    cast(<key_column> as varchar) as <key_column>,

    -- ---- time ---------------------------------------------------------------
    cast(<date_column> as date) as <date_column>,

    -- ---- dimensions ----------------------------------------------------------
    cast(<dimension_column> as varchar) as <dimension_column>,

    -- ---- measures --------------------------------------------------------------
    cast(<measure_column> as number(18, 2)) as <measure_column>,

    -- ---- flags -----------------------------------------------------------------
    cast(<flag_column> as boolean) as <flag_column>

from <source_cte>
