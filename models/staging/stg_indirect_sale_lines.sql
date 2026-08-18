{{ config(
    materialized='view'
) }}

SELECT distinct
    SALE_LINE_ID,
    INV_DATE,
    INV_QTY,
    INV_AMT,
    CONTRACT_ID,
    PRODUCT_ID,
    CUSTOMER_ID,
    DISC_REQUESTED,
    DISC_PAID,
    SUBMISSION_ID,
    LINE_SEVERITY,
    DATE_CREATED,
    DATE_UPDATED,
    'INDIRECT' AS SALE_TYPE,
    'MYSQL' AS SOURCE_SYSTEM
FROM {{ source('sales_raw', 'indirect_sale_lines_raw') }}