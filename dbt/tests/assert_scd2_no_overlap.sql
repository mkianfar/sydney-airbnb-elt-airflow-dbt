-- Fails when two versions of the same listing or host are valid at the same time; a temporal join
-- would then return two dimension rows per fact row and double-count.
select 'dim_listing' as dim, a.listing_id as id, a.valid_from
from {{ ref('dim_listing') }} a
join {{ ref('dim_listing') }} b
  on a.listing_id = b.listing_id
 and a.valid_from < b.valid_from
 and (a.valid_to is null or a.valid_to > b.valid_from)
union all
select 'dim_host', a.host_id, a.valid_from
from {{ ref('dim_host') }} a
join {{ ref('dim_host') }} b
  on a.host_id = b.host_id
 and a.valid_from < b.valid_from
 and (a.valid_to is null or a.valid_to > b.valid_from)
