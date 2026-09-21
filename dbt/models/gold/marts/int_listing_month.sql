{#
  One row per listing per month with the listing and host attributes AS THEY WERE THAT MONTH (SCD2 joins).
  The two listing marts aggregate over this, so the temporal join lives in exactly one place.
#}
select
    f.snap_month                as month,
    f.listing_id,
    f.host_id,
    d.listing_neighbourhood,
    d.property_type,
    d.room_type,
    d.accommodates,
    d.review_scores_rating,
    h.host_is_superhost,
    f.price,
    f.has_availability,
    f.booked_nights_30,
    f.est_revenue_30
from {{ ref('fact_listing_monthly') }} f
join {{ ref('dim_listing') }} d
    on d.listing_id = f.listing_id
   and {{ scd2_valid_on('f.snap_month', 'd') }}
left join {{ ref('dim_host') }} h
    on h.host_id = f.host_id
   and {{ scd2_valid_on('f.snap_month', 'h') }}
