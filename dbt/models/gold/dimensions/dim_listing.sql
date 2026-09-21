-- SCD2 listing dimension. A fact row joins the version where valid_from <= month < valid_to (valid_to NULL = current).
select
    listing_id,
    listing_neighbourhood,
    property_type,
    room_type,
    accommodates,
    review_scores_rating,
    dbt_valid_from::date         as valid_from,
    dbt_valid_to::date           as valid_to,
    (dbt_valid_to is null)       as is_current
from {{ ref('snap_dim_listing') }}
