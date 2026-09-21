{#
  Typed, cleaned Airbnb listings: one row per listing per calendar month, covering every month loaded into bronze.

  The month comes from `scraped_date`, not from the file name. Some monthly files contain rows scraped in a later
  month (07_2020.csv holds 4,780 rows scraped in September, 4,758 of which also appear in 09_2020.csv), so
  the same (listing, month) can arrive twice. The latest scrape wins; a tie goes to the file loaded for the later month.

  This replaces the earlier hard-coded `where month_key = date '2021-04-01'` that had to be edited for every month.
#}
with src as (

    select * from {{ source('bronze', 'airbnb_raw') }}

),

typed as (

    select
        listing_id::bigint                                          as listing_id,
        nullif(trim(scrape_id), '')::bigint                         as scrape_id,
        {{ parse_date_multi('scraped_date') }}                      as scraped_dt,
        {{ parse_date_multi('host_since') }}                        as host_since_dt,

        nullif(trim(host_id), '')::bigint                           as host_id,
        nullif(trim(host_name), '')                                 as host_name,
        case lower(trim(host_is_superhost)) when 't' then true when 'f' then false end as host_is_superhost,
        nullif(trim(host_neighbourhood), '')                        as host_neighbourhood,

        nullif(trim(listing_neighbourhood), '')                     as listing_neighbourhood,
        nullif(trim(property_type), '')                             as property_type,
        nullif(trim(room_type), '')                                 as room_type,
        nullif(trim(accommodates), '')::int                         as accommodates,

        -- strip currency symbols, thousands separators and stray characters before casting
        nullif(regexp_replace(price, '[^0-9\.]', '', 'g'), '')::numeric as price,

        case lower(trim(has_availability)) when 't' then true when 'f' then false end as has_availability,
        nullif(trim(availability_30), '')::int                      as availability_30,
        nullif(trim(number_of_reviews), '')::int                    as number_of_reviews,
        nullif(trim(review_scores_rating), '')::int                 as review_scores_rating,
        nullif(trim(review_scores_accuracy), '')::int               as review_scores_accuracy,
        nullif(trim(review_scores_cleanliness), '')::int            as review_scores_cleanliness,
        nullif(trim(review_scores_checkin), '')::int                as review_scores_checkin,
        nullif(trim(review_scores_communication), '')::int          as review_scores_communication,
        nullif(trim(review_scores_value), '')::int                  as review_scores_value,

        load_month
    from src
    where nullif(trim(listing_id), '') is not null

),

dated as (

    select *, date_trunc('month', scraped_dt)::date as month_key
    from typed
    where scraped_dt is not null

),

ranked as (

    select
        *,
        row_number() over (
            partition by listing_id, month_key
            order by scraped_dt desc, load_month desc
        ) as rn
    from dated

)

select
    listing_id, month_key, scraped_dt, scrape_id, host_id, host_name, host_since_dt, host_is_superhost,
    host_neighbourhood, listing_neighbourhood, property_type, room_type, accommodates, price,
    has_availability, availability_30, number_of_reviews, review_scores_rating, review_scores_accuracy,
    review_scores_cleanliness, review_scores_checkin, review_scores_communication, review_scores_value,
    load_month
from ranked
where rn = 1
