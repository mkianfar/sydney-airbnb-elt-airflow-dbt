-- 2016 Census G01 (selected person characteristics) at LGA level: totals only, typed.
select
    trim(lga_code_2016)          as lga_code,
    nullif(tot_p_m, '')::int     as total_pop_male,
    nullif(tot_p_f, '')::int     as total_pop_female,
    nullif(tot_p_p, '')::int     as total_pop
from {{ source('bronze', 'census_g01_raw_csv') }}
where lga_code_2016 is not null
