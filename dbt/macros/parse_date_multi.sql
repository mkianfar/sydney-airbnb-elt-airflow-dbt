{#
  Parse a text date that may arrive as ISO (2020-05-11), D/M/YYYY (23/9/2009) or D-M-YYYY.
  Returns NULL when no pattern matches, so bad values surface as NULLs instead of failing the whole run.
#}
{% macro parse_date_multi(col) -%}
case
    when trim({{ col }}) ~ '^\d{4}-\d{2}-\d{2}$'       then trim({{ col }})::date
    when trim({{ col }}) ~ '^\d{1,2}/\d{1,2}/\d{4}$'   then to_date(trim({{ col }}), 'DD/MM/YYYY')
    when trim({{ col }}) ~ '^\d{1,2}-\d{1,2}-\d{4}$'   then to_date(trim({{ col }}), 'DD-MM-YYYY')
end
{%- endmacro %}
