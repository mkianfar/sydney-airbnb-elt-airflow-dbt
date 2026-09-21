-- Suburb -> LGA mapping, upper-cased and trimmed. Exact duplicates are removed.
select distinct
    upper(trim(suburb_name)) as suburb_name,
    upper(trim(lga_name))    as lga_name
from {{ source('bronze', 'nsw_lga_suburb_raw_csv') }}
where suburb_name is not null
  and lga_name is not null
