
{{
    config(
        materialized='incremental',
        unique_key='src_sys_id',
        incremental_strategy='merge'
    )
}}
with customer_extract as (
    select distinct
        customer_id,
        customer_number,
        customer_name,
        customer_type,
        industry,
        address,
        city,
        state,
        country,
        email,
        phone,
        date_created,
        date_updated    
    from sales.sales_raw.customer_raw
    where customer_type = 'SMB'
    
{% if is_incremental() %}
      and date_updated >  (
            select coalesce(
                max(src_sys_date_updated),
                '1900-01-01'::timestamp
            )
            from {{ this }}
        )

    {% endif %}

),
customer_val as (
select 
    customer_id as src_sys_id,
    customer_id,
    customer_number,
    customer_name,
    upper(customer_name) customer_name_normalized,
    customer_type,
    industry,
    address,
    city,
    state,
    country,
    email,
    phone,
    date_created as src_sys_date_created,
    date_updated as src_sys_date_updated,
    null as effective_start_date,
    null as effective_end_date,
    'Y' as latest_flag,
    current_timestamp() as date_created,
    current_timestamp() as date_updated,
    'MYSQL' as source_system
from customer_extract
)
select 
    src_sys_id,
    customer_id,
    customer_number,
    customer_name,
    customer_name_normalized,
    customer_type,
    industry,
    address,
    city,
    state,
    country,
    email,
    phone,
    src_sys_date_created,
    src_sys_date_updated,
    effective_start_date,
    effective_end_date,
    latest_flag,
    date_created,
    date_updated,
    source_system
 from customer_val