-- Fails (returns rows) when a loaded month has no snapshot version. That happens when several months are loaded
-- before dbt runs: the snapshots only ever read the newest loaded month.
select m.month_key
from (
    select distinct month_key from {{ ref('silver_listings') }}
    where month_key <= {{ latest_loaded_month() }}
) m
left join {{ ref('snap_dim_listing') }} s on s.month_key = m.month_key
where s.listing_id is null
