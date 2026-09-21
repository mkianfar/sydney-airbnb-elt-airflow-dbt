{# Join condition that picks the dimension row that was valid on `date_col` (Slowly Changing Dimension type 2). #}
{% macro scd2_valid_on(date_col, dim_alias) -%}
{{ date_col }} >= {{ dim_alias }}.valid_from
and ({{ dim_alias }}.valid_to is null or {{ date_col }} < {{ dim_alias }}.valid_to)
{%- endmacro %}
