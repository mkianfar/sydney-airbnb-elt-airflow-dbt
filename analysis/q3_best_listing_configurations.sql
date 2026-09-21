-- Top-5 neighbourhoods by avg revenue per ACTIVE listing (last 12 months),
-- then, for each of those neighbourhoods, rank the (property_type, room_type, accommodates)
-- combos by TOTAL STAYS (only active listings counted).

WITH top5 AS (
  SELECT
    listing_neighbourhood,
    ROUND(AVG(avg_est_revenue_active), 2) AS avg_rev_per_active
  FROM gold.dm_listing_neighbourhood
  WHERE listing_neighbourhood IS NOT NULL
  GROUP BY 1
  ORDER BY avg_rev_per_active DESC
  LIMIT 5
),
-- Fact (month-level metrics)
f AS (
  SELECT
    snap_month::date AS month,
    listing_id::bigint,
    booked_nights_30,
    has_availability
  FROM gold.fact_listing_monthly
  -- If you want to be explicit about the window, uncomment:
  -- WHERE snap_month BETWEEN DATE '2020-05-01' AND DATE '2021-04-01'
),
-- Full SCD2 listing dimension
d AS (
  SELECT
    listing_id::bigint,
    listing_neighbourhood,
    property_type,
    room_type,
    accommodates,
    valid_from::date AS valid_from,
    valid_to::date   AS valid_to
  FROM gold.dim_listing
),
-- SCD2-correct join (listing attributes valid at fact month),
-- and restrict to the top-5 neighbourhoods
joined AS (
  SELECT
    d.listing_neighbourhood,
    d.property_type,
    d.room_type,
    d.accommodates,
    f.booked_nights_30,
    f.has_availability
  FROM f
  JOIN d
    ON f.listing_id = d.listing_id
   AND f.month >= d.valid_from
   AND (d.valid_to IS NULL OR f.month < d.valid_to)
  JOIN top5 t
    ON d.listing_neighbourhood = t.listing_neighbourhood
),
-- Aggregate stays for active listings only
agg AS (
  SELECT
    listing_neighbourhood,
    property_type,
    room_type,
    accommodates,
    SUM(booked_nights_30) FILTER (WHERE has_availability) AS total_stays
  FROM joined
  GROUP BY 1,2,3,4
),
ranked AS (
  SELECT
    listing_neighbourhood,
    property_type,
    room_type,
    accommodates,
    total_stays,
    RANK() OVER (
      PARTITION BY listing_neighbourhood
      ORDER BY total_stays DESC NULLS LAST
    ) AS rank_in_nhood
  FROM agg
)
SELECT
  listing_neighbourhood,
  property_type,
  room_type,
  accommodates,
  total_stays,
  rank_in_nhood
FROM ranked
WHERE rank_in_nhood <= 3
ORDER BY listing_neighbourhood, rank_in_nhood;
