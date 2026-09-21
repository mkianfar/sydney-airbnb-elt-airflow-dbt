{#
  SCD type 2 history of listing attributes, built with dbt's timestamp strategy.

  Each run snapshots only the newest LOADED month (see latest_loaded_month), so history grows by one monthly
  version per listing per run: [valid_from, valid_to) is exactly one month unless a listing skips months.
  Load a month, then run dbt, in month order. Running dbt after loading several months at once would skip the
  older ones; the test assert_snapshots_cover_all_months fails when that happens.
#}
{% snapshot snap_dim_listing %}

{{
    config(
        target_schema='silver',
        unique_key='listing_id',
        strategy='timestamp',
        updated_at='month_key'
    )
}}

select
    listing_id,
    month_key,
    listing_neighbourhood,
    property_type,
    room_type,
    accommodates,
    review_scores_rating
from {{ ref('silver_listings') }}
where month_key = {{ latest_loaded_month() }}

{% endsnapshot %}
