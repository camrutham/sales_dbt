{{ config(materialized='table') }}

SELECT
    c.c_custkey as Customer_ID,
    c.c_name as Cusotmer_Name,
    o.o_orderpriority as priority,
    COUNT(li.l_linenumber) AS TOTAL_ORDERS,
    SUM(li.l_quantity) AS TOTAL_QTY,
    SUM(li.l_quantity*li.l_extendedprice) AS TOTAL_GROSS_SALES,
    SUM(li.l_discount) AS TOTAL_DISCOUNT,
    CURRENT_TIMESTAMP() AS ETL_DATE_CREATED
FROM sales.sales_canonical2.lineitem li
left join sales.sales_canonical2.orders o on o.o_orderkey = li.l_orderkey
LEFT JOIN sales.sales_canonical2.customers c
    ON c.c_custkey = o.o_custkey
GROUP BY
    c.c_custkey,
    c.C_NAME,
    o.o_orderpriority
