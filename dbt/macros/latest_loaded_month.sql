{#
  The newest month that has been loaded into bronze, by FILE month (load_month), not by scraped_date.
  Files can contain rows scraped in a later month (07_2020.csv has September rows), so "newest month in the data"
  is not the month being processed. Snapshots slice on this value and gold only publishes months up to it.
#}
{% macro latest_loaded_month() -%}
(select max(load_month) from {{ source('bronze', 'airbnb_raw') }})
{%- endmacro %}
