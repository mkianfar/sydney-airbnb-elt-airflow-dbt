-- Local Government Areas: code and name.
select distinct lga_code, lga_name
from {{ ref('silver_nsw_lga_code') }}
where lga_code is not null
