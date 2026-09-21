-- Reference data: 2016 Census G01 population by LGA, with the LGA name attached.
select c.lga_code, k.lga_name, c.total_pop_male, c.total_pop_female, c.total_pop
from {{ ref('silver_census_g01') }} c
left join {{ ref('silver_nsw_lga_code') }} k using (lga_code)
