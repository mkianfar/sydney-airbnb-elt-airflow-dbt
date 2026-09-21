-- Data mart: Airbnb performance per listing neighbourhood per month.
with a as (

    select
        listing_neighbourhood,
        month,
        {{ listing_month_aggregates() }}
    from {{ ref('int_listing_month') }}
    group by listing_neighbourhood, month

)

select
    a.listing_neighbourhood,
    a.month,
    a.listings_total,
    a.listings_active,
    a.listings_inactive,
    {{ listing_month_metrics('listing_neighbourhood') }}
from a
window w as (partition by a.listing_neighbourhood order by a.month)
order by a.listing_neighbourhood, a.month
