-- Q2. Is the median age of an LGA correlated with revenue per active listing (last 12 months)?
-- Pearson correlation across LGAs.

WITH bounds AS (
  SELECT
    (MAX(snap_month)::date)                               AS max_m,
    (MAX(snap_month)::date - INTERVAL '11 months')::date  AS min_m
  FROM gold.fact_listing_monthly
),
lga_12m AS (
  SELECT
    f.lga_code,
    SUM(CASE WHEN f.has_availability THEN f.est_revenue_30 ELSE 0 END)::numeric
      / NULLIF(SUM(CASE WHEN f.has_availability THEN 1 ELSE 0 END), 0) AS rev_per_active
  FROM gold.fact_listing_monthly f
  JOIN bounds b
    ON f.snap_month BETWEEN b.min_m AND b.max_m
  GROUP BY 1
),
joined AS (
  SELECT
    l.lga_code,
    l.rev_per_active,
    g2.median_age_persons
  FROM lga_12m l
  JOIN gold.dim_census_g02 g2 USING (lga_code)
  WHERE l.rev_per_active IS NOT NULL
    AND g2.median_age_persons IS NOT NULL
)
SELECT
  COUNT(*)                                      AS n_lgas,
  ROUND(AVG(rev_per_active), 2)                 AS avg_rev_per_active,
  ROUND(AVG(median_age_persons), 2)             AS avg_median_age,
  -- Pearson correlation in Postgres:
  ROUND(CORR(rev_per_active, median_age_persons)::numeric, 4) AS corr_rev_age
FROM joined;
