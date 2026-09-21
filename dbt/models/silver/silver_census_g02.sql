-- 2016 Census G02 (selected medians and averages) at LGA level, typed.
select
    trim(lga_code_2016)                                   as lga_code,
    nullif(median_age_persons, '')::int                   as median_age_persons,
    nullif(median_mortgage_repay_monthly, '')::int        as median_mortgage_monthly,
    nullif(median_tot_prsnl_inc_weekly, '')::int          as median_personal_income_weekly,
    nullif(median_rent_weekly, '')::int                   as median_rent_weekly,
    nullif(median_tot_fam_inc_weekly, '')::int            as median_family_income_weekly,
    nullif(average_num_psns_per_bedroom, '')::float       as avg_persons_per_bedroom,
    nullif(median_tot_hhd_inc_weekly, '')::int            as median_household_income_weekly,
    nullif(average_household_size, '')::float             as average_household_size
from {{ source('bronze', 'census_g02_raw_csv') }}
where lga_code_2016 is not null
