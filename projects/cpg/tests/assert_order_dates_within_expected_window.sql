-- Singular test: order dates should fall inside the window the source system
-- actually covers. A date outside it usually means a bad cast rather than a
-- real order, which is exactly the kind of thing a text-to-date conversion
-- gets wrong quietly.
--
-- A singular test is just a select. dbt runs it and fails if it returns rows.

select
    record_id,
    order_date

from {{ ref('stg_cpg_records') }}

where order_date < cast('2024-01-01' as date)
   or order_date > cast('2025-12-31' as date)
