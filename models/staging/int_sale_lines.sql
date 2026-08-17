{{ config(
    materialized='view'
) }}

WITH direct_sales AS (

    SELECT *
    FROM {{ ref('stg_direct_sale_lines') }}

),

indirect_sales AS (

    SELECT *
    FROM {{ ref('stg_indirect_sale_lines') }}

)

SELECT * FROM direct_sales

UNION ALL

SELECT * FROM indirect_sales