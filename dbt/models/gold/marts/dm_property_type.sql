-- Data mart: Airbnb performance per property type, room type and capacity per month.
with a as (

    select
        property_type,
        room_type,
        accommodates,
        month,
        {{ listing_month_aggregates() }}
    from {{ ref('int_listing_month') }}
    group by property_type, room_type, accommodates, month

)

select
    a.property_type,
    a.room_type,
    a.accommodates,
    a.month,
    a.listings_total,
    a.listings_active,
    a.listings_inactive,
    {{ listing_month_metrics('property_type, room_type, accommodates') }}
from a
window w as (partition by a.property_type, a.room_type, a.accommodates order by a.month)
order by a.property_type, a.room_type, a.accommodates, a.month
