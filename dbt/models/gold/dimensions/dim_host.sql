-- SCD2 host dimension. Same validity convention as dim_listing.
select
    host_id,
    host_name,
    host_is_superhost,
    host_neighbourhood,
    dbt_valid_from::date         as valid_from,
    dbt_valid_to::date           as valid_to,
    (dbt_valid_to is null)       as is_current
from {{ ref('snap_dim_host') }}
