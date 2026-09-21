-- Q4. How many hosts run more than one listing, and how many of those spread across several LGAs?
-- Second query: each host's primary LGA (first 20 shown).

WITH f AS (
  SELECT host_id, listing_id, lga_code
  FROM gold.fact_listing_monthly
  WHERE lga_code IS NOT NULL
),
host_span AS (
  SELECT
    host_id,
    COUNT(DISTINCT listing_id) AS listings,
    COUNT(DISTINCT lga_code)   AS lgas
  FROM f
  GROUP BY 1
)
SELECT
  COUNT(*) FILTER (WHERE listings > 1)                              AS multi_hosts,
  COUNT(*) FILTER (WHERE listings > 1 AND lgas = 1)                 AS multi_hosts_one_lga,
  COUNT(*) FILTER (WHERE listings > 1 AND lgas > 1)                 AS multi_hosts_multi_lga,
  ROUND(
    100.0 * COUNT(*) FILTER (WHERE listings > 1 AND lgas > 1)
      / NULLIF(COUNT(*) FILTER (WHERE listings > 1), 0)
  , 2) AS pct_multi_lga
FROM host_span;


WITH f AS (
  SELECT host_id, listing_id, lga_code
  FROM gold.fact_listing_monthly
  WHERE lga_code IS NOT NULL
),
host_lga AS (
  SELECT host_id, lga_code, COUNT(DISTINCT listing_id) AS listings_in_lga
  FROM f
  GROUP BY 1,2
),
ranked AS (
  SELECT
    host_id, lga_code, listings_in_lga,
    RANK() OVER (PARTITION BY host_id ORDER BY listings_in_lga DESC, lga_code) AS r
  FROM host_lga
)
SELECT host_id, lga_code AS primary_lga, listings_in_lga
FROM ranked
WHERE r = 1
LIMIT 20;
