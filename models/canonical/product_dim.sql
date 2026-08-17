
{{
    config(
        materialized='incremental',
        unique_key='src_sys_id',
        incremental_strategy='merge'
    )
}}
WITH product_extract AS (

    SELECT DISTINCT
        product_id,
        product_code,
        product_name,
        product_category,
        product_subcategory,
        brand,
        manufacturer,
        unit_price,
        product_status,
        date_created,
        date_updated

    FROM sales.sales_raw.product_raw
    
    {% if is_incremental() %}

    WHERE date_updated > (
        SELECT COALESCE(
            MAX(src_sys_date_updated),
            '1900-01-01'::TIMESTAMP_NTZ
        )
        FROM {{ this }}
    )

    {% endif %}

),
product_val as (
select 
    product_id as src_sys_id,
    product_id,
    product_code,
    product_name,
    upper(product_name) product_name_normalized,
    product_category,
    product_subcategory,
    brand,
    manufacturer,
    unit_price,
    product_status,
    case when product_status ='Active' then 'Y' else 'N' end as product_active_flag,
    date_created as src_sys_date_created,
    date_updated as src_sys_date_updated,
    'Y' as latest_flag,
    current_timestamp() as date_created,
    current_timestamp() as date_updated,
    'MYSQL' as source_system
from product_extract
)
select 
    src_sys_id,
    product_id,
    product_code,
    product_name,
    product_name_normalized,
    product_category,
    product_subcategory,
    brand,
    manufacturer,
    unit_price,
    product_status,
    product_active_flag,
    src_sys_date_created,
    src_sys_date_updated,
    latest_flag,
    date_created,
    date_updated,
    source_system
 from product_val