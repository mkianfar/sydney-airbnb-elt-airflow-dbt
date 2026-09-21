{#
  Data mart: hosts and estimated revenue per host_neighbourhood_lga per month.
  The host's neighbourhood as it was that month (SCD2) is resolved to an LGA through dim_place.
  Hosts whose neighbourhood matches no NSW LGA or suburb (interstate, overseas, blank) are reported under the
  explicit bucket 'UNMAPPED' rather than dropped - in this data that is ~38% of listing-months.
#}
with host_month as (

    select
        f.snap_month                   as month,
        f.host_id,
        f.est_revenue_30,
        f.has_availability,
        coalesce(p.lga_name, 'UNMAPPED')  as host_neighbourhood_lga
    from {{ ref('fact_listing_monthly') }} f
    join {{ ref('dim_host') }} h
        on h.host_id = f.host_id
       and {{ scd2_valid_on('f.snap_month', 'h') }}
    left join {{ ref('dim_place') }} p
        on p.place_key = {{ place_key('h.host_neighbourhood') }}

)

select
    host_neighbourhood_lga,
    month,
    count(distinct host_id)                                             as distinct_hosts,
    sum(est_revenue_30) filter (where has_availability)                 as estimated_revenue,
    round(
        sum(est_revenue_30) filter (where has_availability) / nullif(count(distinct host_id), 0), 2
    )                                                                   as estimated_revenue_per_host
from host_month
group by host_neighbourhood_lga, month
order by host_neighbourhood_lga, month
