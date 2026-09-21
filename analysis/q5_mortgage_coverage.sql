-- Q5. For hosts with a single listing, what share earn at least a year of their LGA's median mortgage repayment
-- (median monthly repayment x 12) from estimated active-listing revenue?

WITH f AS (
  SELECT host_id, listing_id, lga_code,
         SUM(COALESCE(est_revenue_30,0)) FILTER (WHERE has_availability) AS rev_12m
  FROM gold.fact_listing_monthly
  GROUP BY 1,2,3
),
counts AS (
  SELECT host_id, COUNT(*) AS n_listings
  FROM f GROUP BY 1
),
single_hosts AS (
  SELECT f.*
  FROM f
  JOIN counts c USING (host_id)
  WHERE c.n_listings = 1
),
final AS (
  SELECT
    o.host_id,
    o.lga_code,
    o.rev_12m,
    g.median_mortgage_monthly * 12 AS annual_mortgage
  FROM single_hosts o
  JOIN gold.dim_census_g02 g USING (lga_code)
)
SELECT
  l.lga_name,
  f.lga_code,
  COUNT(*) AS single_hosts,
  SUM(CASE WHEN rev_12m >= annual_mortgage THEN 1 ELSE 0 END) AS can_cover,
  ROUND(100.0 * SUM(CASE WHEN rev_12m >= annual_mortgage THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*),0), 2) AS pct_cover
FROM final f
JOIN gold.dim_lga l USING (lga_code)
GROUP BY 1,2
ORDER BY pct_cover DESC, l.lga_name;
