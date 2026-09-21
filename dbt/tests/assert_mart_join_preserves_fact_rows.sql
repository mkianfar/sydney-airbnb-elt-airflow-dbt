-- The SCD2 join must return exactly one row per fact row: fewer means a fact row found no dimension version,
-- more means it found several (fan-out). Either way the marts would be wrong.
select f.n as fact_rows, i.n as joined_rows
from (select count(*) as n from {{ ref('fact_listing_monthly') }}) f
cross join (select count(*) as n from {{ ref('int_listing_month') }}) i
where f.n <> i.n
