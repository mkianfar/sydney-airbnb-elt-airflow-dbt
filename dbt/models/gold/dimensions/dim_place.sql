{#
  Resolves a place name to an LGA. Used for BOTH listing_neighbourhood (fact table) and host_neighbourhood (host mart),
  so the two always agree. The earlier version resolved them with opposite precedence.

  Matching is on a normalised key (upper-case, letters and digits only). An LGA name wins over a suburb of the same
  name; a suburb that appears in several LGAs resolves to the lowest LGA code, so the result is one row per key.
#}
with lga_names as (

    select {{ place_key('lga_name') }} as place_key, lga_code, lga_name, 'lga_name' as match_type, 1 as priority
    from {{ ref('silver_nsw_lga_code') }}

),

suburbs as (

    select {{ place_key('s.suburb_name') }} as place_key, c.lga_code, c.lga_name, 'suburb' as match_type, 2 as priority
    from {{ ref('silver_nsw_lga_suburb') }} s
    join {{ ref('silver_nsw_lga_code') }} c on s.lga_name = c.lga_name

),

ranked as (

    select
        *,
        row_number() over (partition by place_key order by priority, lga_code) as rn
    from (select * from lga_names union all select * from suburbs) u

)

select place_key, lga_code, lga_name, match_type
from ranked
where rn = 1
