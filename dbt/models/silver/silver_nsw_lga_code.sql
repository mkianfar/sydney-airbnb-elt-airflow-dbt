-- LGA master list. Codes are unified to 'LGA' + 5 digits (10300 -> LGA10300) so they join to the Census files,
-- which use the prefixed form. Names are upper-cased and trimmed for stable joins.
with src as (

    select
        trim(lga_code)::text     as code_raw,
        upper(trim(lga_name))    as lga_name
    from {{ source('bronze', 'nsw_lga_code_raw_csv') }}
    where lga_code is not null

),

coded as (

    select
        case
            when code_raw ~ '^\d+$'          then 'LGA' || lpad(code_raw, 5, '0')
            when upper(code_raw) like 'LGA%' then upper(code_raw)
        end as lga_code,
        lga_name
    from src

)

select lga_code, lga_name
from coded
where lga_code is not null
