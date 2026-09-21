{#
  Write models to exactly the schema named in their config (`silver`, `gold`) instead of dbt's default
  "<target schema>_<custom schema>" (which produced names like dbt_<user>_gold). One database = one environment.
#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
