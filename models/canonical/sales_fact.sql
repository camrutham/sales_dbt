{{ config(
    materialized='incremental',
    unique_key=['SALE_LINE_ID', 'SALE_TYPE'],
    incremental_strategy='merge',
    alias='SALES_FACT'
) }}

WITH source_data AS (

    SELECT
        SALE_LINE_ID,
        CUSTOMER_ID,
        PRODUCT_ID,
        CONTRACT_ID,
        SUBMISSION_ID,
        SALE_TYPE,
        INV_DATE,
        INV_QTY,
        INV_AMT,
        DISC_REQUESTED,
        DISC_PAID,
        LINE_SEVERITY,
        DATE_CREATED,
        DATE_UPDATED,
        SOURCE_SYSTEM

    FROM {{ ref('int_sale_lines') }}

    {% if is_incremental() %}

    WHERE COALESCE(DATE_UPDATED, DATE_CREATED) >
        COALESCE(
            (
                SELECT MAX(SRC_SYS_DATE_UPDATED)
                FROM {{ this }}
            ),
            '1900-01-01'::TIMESTAMP_NTZ
        )

    {% endif %}

),

final AS (

    SELECT

        SALE_LINE_ID,

        CUSTOMER_ID,

        PRODUCT_ID,

        CONTRACT_ID,

        SUBMISSION_ID,

        SALE_TYPE,

        INV_DATE,

        INV_QTY,

        INV_AMT,

        DISC_REQUESTED,

        DISC_PAID,

        LINE_SEVERITY,

        /* ================================
           BUSINESS CALCULATIONS
           ================================ */

        INV_AMT AS GROSS_SALES,

        INV_AMT - COALESCE(DISC_PAID, 0)
            AS NET_AMOUNT,

        COALESCE(DISC_PAID, 0)
            AS DISCOUNT_AMOUNT,

        CASE
            WHEN COALESCE(INV_AMT, 0) = 0
                THEN 0
            ELSE
                (
                    COALESCE(DISC_PAID, 0)
                    / INV_AMT
                ) * 100
        END AS DISCOUNT_PERCENT,

        CASE
            WHEN UPPER(LINE_SEVERITY)
                 IN ('HIGH', 'CRITICAL')
                THEN 'Y'
            ELSE 'N'
        END AS LINE_SEVERITY_FLAG,

        /* ================================
           SOURCE AUDIT
           ================================ */

        DATE_CREATED AS SRC_SYS_DATE_CREATED,

        DATE_UPDATED AS SRC_SYS_DATE_UPDATED,

        /* ================================
           ETL AUDIT
           ================================ */

        CURRENT_TIMESTAMP() AS ETL_DATE_CREATED,

        CURRENT_TIMESTAMP() AS ETL_DATE_UPDATED,

        SOURCE_SYSTEM

    FROM source_data

)

SELECT *
FROM final