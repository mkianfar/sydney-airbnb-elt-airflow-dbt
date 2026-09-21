{#
  Grain: one row per listing per month. Only keys and measures live here; descriptive attributes (neighbourhood,
  property type, superhost, ...) come from the SCD2 dimensions at query time.

  est_revenue_30 = price x nights not available in the next 30 days (30 - availability_30).

  Only months up to the newest loaded month are published: silver may already hold later-dated rows (see
  latest_loaded_month), but their dimension versions do not exist until that month is processed.
#}
select
    l.month_key                                       as snap_month,
    l.listing_id,
    l.host_id,
    p.lga_code,
    l.price,
    l.availability_30,
    l.has_availability,
    30 - l.availability_30                            as booked_nights_30,
    l.price * (30 - l.availability_30)                as est_revenue_30
from {{ ref('silver_listings') }} l
left join {{ ref('dim_place') }} p
    on p.place_key = {{ place_key('l.listing_neighbourhood') }}
where l.month_key <= {{ latest_loaded_month() }}
