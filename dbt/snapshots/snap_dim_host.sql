{# SCD type 2 history of host attributes; same newest-loaded-month-only approach as snap_dim_listing. #}
{% snapshot snap_dim_host %}

{{
    config(
        target_schema='silver',
        unique_key='host_id',
        strategy='timestamp',
        updated_at='month_key'
    )
}}

-- one row per host: a host with several listings takes the values from their most recent scrape
select distinct on (host_id)
    host_id,
    month_key,
    host_name,
    host_is_superhost,
    host_neighbourhood
from {{ ref('silver_listings') }}
where host_id is not null
  and month_key = {{ latest_loaded_month() }}
order by host_id, scraped_dt desc, listing_id

{% endsnapshot %}
