{{ config(
    materialized='incremental',
    unique_key=['CONTRACT_ID', 'EFFECTIVE_START_DATE'],
    incremental_strategy='merge',
    alias='CONTRACT_DIM'
) }}

-- ============================================================
-- CONTRACT DIMENSION (SCD Type 2)
-- Stores 1 record per contract version using explicit START_DATE & END_DATE
-- ============================================================

WITH raw_data AS (
    SELECT DISTINCT
        c.*
    FROM {{ source('sales_raw', 'contract_raw') }} c
    {% if is_incremental() %}
    WHERE COALESCE(c.DATE_UPDATED, c.DATE_CREATED) > COALESCE(
        (SELECT MAX(SRC_SYS_DATE_UPDATED) FROM {{ this }}),
        '1900-01-01'::TIMESTAMP_NTZ
    )
    {% endif %}
),

scd_records AS (
    SELECT
        -- Surrogate / business keys
        CAST(r.CONTRACT_ID          AS NUMBER(38,0))    AS SRC_SYS_ID,
        CAST(r.CONTRACT_ID          AS VARCHAR)         AS CONTRACT_ID,
        CAST(r.CONTRACT_NUMBER      AS VARCHAR)         AS CONTRACT_NUMBER,
        CAST(r.CONTRACT_NAME        AS VARCHAR)         AS CONTRACT_NAME,
        CAST(NULL                   AS VARCHAR)         AS CONTRACT_NAME_NORMALIZED,
        CAST(r.CUSTOMER_ID          AS NUMBER(38,0))    AS CUSTOMER_ID,
        CAST(r.CONTRACT_TYPE        AS VARCHAR)         AS CONTRACT_TYPE,
        CAST(r.START_DATE           AS DATE)            AS START_DATE,
        CAST(r.END_DATE             AS DATE)            AS END_DATE,
        CAST(r.CONTRACT_VALUE       AS NUMBER(18,2))    AS CONTRACT_VALUE,
        CAST(r.CONTRACT_STATUS      AS VARCHAR)         AS CONTRACT_STATUS,
        CAST(r.SALES_REGION         AS VARCHAR)         AS SALES_REGION,
        CAST(r.ACCOUNT_MANAGER      AS VARCHAR)         AS ACCOUNT_MANAGER,

        -- Source audit
        CAST(r.DATE_CREATED         AS TIMESTAMP_NTZ)   AS SRC_SYS_DATE_CREATED,
        CAST(r.DATE_UPDATED         AS TIMESTAMP_NTZ)   AS SRC_SYS_DATE_UPDATED,

        -- SCD tracking columns (mapped directly from version START_DATE & END_DATE)
        CAST(r.START_DATE AS DATE)                      AS EFFECTIVE_START_DATE,
        COALESCE(CAST(r.END_DATE AS DATE), CAST('9999-12-31' AS DATE)) AS EFFECTIVE_END_DATE,
        CASE
            WHEN LEAD(r.START_DATE) OVER (
                PARTITION BY r.CONTRACT_ID 
                ORDER BY r.START_DATE ASC, r.DATE_UPDATED ASC, r.DATE_CREATED ASC
            ) IS NULL THEN TRUE
            ELSE FALSE
        END                                             AS LATEST_FLAG,

        -- ETL audit
        CAST(CURRENT_TIMESTAMP()    AS TIMESTAMP_NTZ)   AS DATE_CREATED,
        CAST(CURRENT_TIMESTAMP()    AS TIMESTAMP_NTZ)   AS DATE_UPDATED,
        CAST('sales'                AS VARCHAR)         AS SOURCE_SYSTEM
    FROM raw_data r
)

{% if is_incremental() %}

, records_to_expire AS (
    SELECT
        t.SRC_SYS_ID,
        t.CONTRACT_ID,
        t.CONTRACT_NUMBER,
        t.CONTRACT_NAME,
        t.CONTRACT_NAME_NORMALIZED,
        t.CUSTOMER_ID,
        t.CONTRACT_TYPE,
        t.START_DATE,
        t.END_DATE,
        t.CONTRACT_VALUE,
        t.CONTRACT_STATUS,
        t.SALES_REGION,
        t.ACCOUNT_MANAGER,
        t.SRC_SYS_DATE_CREATED,
        t.SRC_SYS_DATE_UPDATED,
        t.EFFECTIVE_START_DATE,
        t.EFFECTIVE_END_DATE,
        FALSE                                           AS LATEST_FLAG,
        t.DATE_CREATED,
        CAST(CURRENT_TIMESTAMP() AS TIMESTAMP_NTZ)      AS DATE_UPDATED,
        t.SOURCE_SYSTEM
    FROM {{ this }} t
    INNER JOIN scd_records s
        ON t.CONTRACT_ID = s.CONTRACT_ID
    WHERE t.LATEST_FLAG = TRUE
      AND t.EFFECTIVE_START_DATE < s.EFFECTIVE_START_DATE
)

SELECT * FROM records_to_expire
UNION ALL
SELECT * FROM scd_records

{% else %}

SELECT * FROM scd_records

{% endif %}
