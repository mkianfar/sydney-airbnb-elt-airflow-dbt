{# Normalise a place name for matching: upper-case, letters and digits only ("Canterbury-Bankstown" -> CANTERBURYBANKSTOWN). #}
{% macro place_key(col) -%}
regexp_replace(upper(trim({{ col }})), '[^A-Z0-9]', '', 'g')
{%- endmacro %}
