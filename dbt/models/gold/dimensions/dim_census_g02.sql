-- Reference data: 2016 Census G02 medians and averages by LGA, with the LGA name attached.
select
    c.lga_code,
    k.lga_name,
    c.median_age_persons,
    c.median_mortgage_monthly,
    c.median_personal_income_weekly,
    c.median_rent_weekly,
    c.median_family_income_weekly,
    c.avg_persons_per_bedroom,
    c.median_household_income_weekly,
    c.average_household_size
from {{ ref('silver_census_g02') }} c
left join {{ ref('silver_nsw_lga_code') }} k using (lga_code)
