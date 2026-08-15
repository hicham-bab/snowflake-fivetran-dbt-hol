-- Singular test: the business rule that makes recognised_revenue trustworthy.
--
-- The raw data does carry an order_total on cancelled orders (192 of them), so
-- anyone summing order_total overstates revenue. recognised_revenue exists to
-- fix that. This test makes sure it stays fixed.

select
    record_id,
    order_status,
    order_total,
    recognised_revenue

from {{ ref('cpg_order_performance') }}

where is_cancelled_order = true
  and recognised_revenue <> 0
