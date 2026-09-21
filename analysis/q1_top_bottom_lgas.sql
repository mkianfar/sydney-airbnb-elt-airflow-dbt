-- Q1. Which 3 LGAs earn the most, and which 3 the least, per ACTIVE listing over the last 12 months?
-- Revenue per active listing = estimated 30-day revenue summed over active listing-months / number of those listing-months.
-- Census G01/G02 columns are attached to compare the extremes.

WITH bounds AS (
  SELECT
    (MAX(snap_month)::date)                               AS max_m,
    (MAX(snap_month)::date - INTERVAL '11 months')::date  AS min_m
  FROM gold.fact_listing_monthly
),
lga_12m AS (
  SELECT
    f.lga_code,
    -- revenue per active listing-month
    SUM(CASE WHEN f.has_availability THEN f.est_revenue_30 ELSE 0 END)::numeric
      / NULLIF(SUM(CASE WHEN f.has_availability THEN 1 ELSE 0 END), 0) AS rev_per_active
  FROM gold.fact_listing_monthly f
  JOIN bounds b
    ON f.snap_month BETWEEN b.min_m AND b.max_m
  GROUP BY 1
),
ranked AS (
  SELECT
    l.*,
    RANK()  OVER (ORDER BY rev_per_active DESC) AS r_desc,
    RANK()  OVER (ORDER BY rev_per_active ASC)  AS r_asc
  FROM lga_12m l
),
pick6 AS (
  SELECT lga_code, rev_per_active, 'TOP_3' AS bucket
  FROM ranked WHERE r_desc <= 3
  UNION ALL
  SELECT lga_code, rev_per_active, 'BOTTOM_3' AS bucket
  FROM ranked WHERE r_asc <= 3
)
SELECT
  p.bucket,
  g02.lga_name,
  ROUND(p.rev_per_active, 2)                         AS rev_per_active,
  g02.median_age_persons,
  g02.average_household_size,
  -- If you only loaded totals in G01, these give scale; if you have age buckets, add them here.
  g01.total_pop_male,
  g01.total_pop_female,
  g01.total_pop
FROM pick6 p
LEFT JOIN gold.dim_census_g02 g02 USING (lga_code)
LEFT JOIN gold.dim_census_g01 g01 USING (lga_code)
ORDER BY  rev_per_active DESC;
