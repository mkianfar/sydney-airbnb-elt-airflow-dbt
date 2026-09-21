{#
  The metric set shared by dm_listing_neighbourhood and dm_property_type.
  Aggregates run over int_listing_month (one row per listing per month, dimensions as they were that month).
#}
{% macro listing_month_aggregates() -%}
    count(*)                                              as listings_total,
    sum(has_availability::int)                            as listings_active,
    sum((not has_availability)::int)                      as listings_inactive,
    min(price) filter (where has_availability)            as min_price_active,
    max(price) filter (where has_availability)            as max_price_active,
    percentile_cont(0.5) within group (order by price)
        filter (where has_availability)                   as median_price_active,
    avg(price) filter (where has_availability)            as avg_price_active,
    count(distinct host_id)                               as hosts_total,
    count(distinct case when host_is_superhost then host_id end) as hosts_super,
    avg(review_scores_rating) filter (where has_availability)    as avg_rating_active,
    sum(booked_nights_30) filter (where has_availability) as total_stays_active,
    avg(est_revenue_30) filter (where has_availability)   as avg_est_revenue_active
{%- endmacro %}

{# Final columns for a mart; `partition_cols` is the comma-separated grouping used for month-over-month change. #}
{% macro listing_month_metrics(partition_cols) -%}
    round(100.0 * a.listings_active / nullif(a.listings_total, 0), 2)  as active_listings_rate,
    a.min_price_active,
    a.max_price_active,
    a.median_price_active,
    a.avg_price_active,
    a.hosts_total,
    round(100.0 * a.hosts_super / nullif(a.hosts_total, 0), 2)          as superhost_rate,
    a.avg_rating_active,
    round(100.0 * (a.listings_active - lag(a.listings_active) over w)
          / nullif(lag(a.listings_active) over w, 0), 2)                as pct_change_active,
    round(100.0 * (a.listings_inactive - lag(a.listings_inactive) over w)
          / nullif(lag(a.listings_inactive) over w, 0), 2)              as pct_change_inactive,
    a.total_stays_active,
    a.avg_est_revenue_active
{%- endmacro %}
