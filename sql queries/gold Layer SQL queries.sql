-- ==============================================================================
-- GOLD LAYER: Dimension, Fact & Report Views
-- Purpose: Creates all gold-layer views (dimensions, facts, and reports).
-- Usage:   Run this entire script in one go as a single execution unit.
--          Safe to re-run at any time — each view is dropped before recreation.
-- ==============================================================================

DO $$
BEGIN

    -- =========================================================================
    -- SECTION 1: DROP ALL EXISTING VIEWS (reverse dependency order)
    -- =========================================================================
    RAISE NOTICE 'Dropping existing gold views...';
    DROP VIEW IF EXISTS gold.rpt_customer_report CASCADE;
    DROP VIEW IF EXISTS gold.rpt_product_report CASCADE;
    DROP VIEW IF EXISTS gold.fact_sales CASCADE;
    DROP VIEW IF EXISTS gold.dim_products CASCADE;
    DROP VIEW IF EXISTS gold.dim_customers CASCADE;

    -- =========================================================================
    -- SECTION 2: DIMENSION VIEWS
    -- =========================================================================

    -- 2.1 dim_customers
    -- Combines CRM customer info + ERM customer details + ERM customer location
    -- Source: silver.crm_cust_info, silver.erm_customers, silver.erm_customer_location
    -- -------------------------------------------------------------------------
    RAISE NOTICE 'Creating view gold.dim_customers...';
    CREATE VIEW gold.dim_customers AS
    SELECT 
        ROW_NUMBER() OVER (ORDER BY ci.cst_id) AS customer_id,
        ci.cst_id             AS customer_key,
        ci.cst_firstname      AS first_name,
        ci.cst_lastname       AS last_name,
        ec.birth_date,
        CASE 
            WHEN ci.cst_gndr != 'n/a' THEN ci.cst_gndr
            ELSE COALESCE(ec.gender, 'n/a')
        END                   AS gender,
        ci.cst_marital_status AS marital_status,
        CASE 
            WHEN country IS NULL OR TRIM(country) = '' or TRIM(country) = 'n/a' THEN 'unknown'
            ELSE TRIM(country)
        END                   AS country,
        ci.cst_create_date    AS create_date
    FROM silver.crm_cust_info ci
    LEFT JOIN silver.erm_customers ec        ON ci.cst_key = ec.cid
    LEFT JOIN silver.erm_customer_location el ON ci.cst_key = el.cid;

    -- 2.2 dim_products
    -- Combines CRM product info + ERM product categories
    -- Only includes active products (no end date)
    -- Source: silver.crm_prd_info, silver.erm_product_category
    -- -------------------------------------------------------------------------
    RAISE NOTICE 'Creating view gold.dim_products...';
    CREATE VIEW gold.dim_products AS
    SELECT 
        ROW_NUMBER() OVER (ORDER BY pi.prd_id) AS product_key,
        pi.prd_key        AS product_id,
        pi.prd_nm         AS product_name,
        pi.cat_id         AS category_id,
        pc.category,
        pc.subcategory,
        pc.maintenance,
        pi.prd_cost       AS cost,
        pi.prd_line       AS product_line,
        pi.prd_start_dt   AS start_date,
        pi.prd_end_dt     AS end_date
    FROM silver.crm_prd_info pi
    LEFT JOIN silver.erm_product_category pc ON pi.cat_id = pc.id
    WHERE prd_end_dt IS NULL;

    -- =========================================================================
    -- SECTION 3: FACT VIEWS
    -- =========================================================================

    -- 3.1 fact_sales
    -- Joins sales details with customer and product dimensions
    -- Source: silver.crm_sales_details, gold.dim_products, gold.dim_customers
    -- -------------------------------------------------------------------------
    RAISE NOTICE 'Creating view gold.fact_sales...';
    CREATE VIEW gold.fact_sales AS
    SELECT 
        sd.sls_ord_num    AS order_number,
        dp.product_key,
        dc.customer_key,
        sd.sls_order_dt   AS order_date,
        sd.sls_ship_dt    AS shipping_date,
        sd.sls_due_dt     AS due_date,
        sd.sls_sales      AS sales_amount,
        sd.sls_quantity   AS quantity,
        sd.sls_price      AS unit_price
    FROM silver.crm_sales_details sd
    LEFT JOIN gold.dim_products dp  ON sd.sls_prd_key = dp.product_id
    LEFT JOIN gold.dim_customers dc ON sd.sls_cust_id = dc.customer_key;


END $$;

-- =============================================================================
-- SECTION 4: REPORT VIEWS
-- =============================================================================

-- 4.1 rpt_product_report
-- Comprehensive product metrics and KPIs
-- Highlights:
--   • Product details (name, category, subcategory, cost)
--   • Revenue segmentation (High-Performer, Mid-Range, Low-Performer)
--   • Aggregated metrics (orders, sales, quantity, customers, lifespan)
--   • KPIs (recency, average order revenue, average monthly revenue)
-- -------------------------------------------------------------------------
DROP VIEW IF EXISTS gold.rpt_product_report;
CREATE VIEW gold.rpt_product_report AS
WITH product_metrics AS (
    SELECT 
        p.product_key,
        p.product_id,
        p.product_name,
        p.category,
        p.subcategory,
        p.cost,
        COUNT(DISTINCT f.order_number)  AS total_orders,
        SUM(f.sales_amount)             AS total_sales,
        SUM(f.quantity)                  AS total_quantity,
        COUNT(DISTINCT f.customer_key)  AS total_customers,
        MAX(f.order_date)               AS last_sale_date,
        MIN(f.order_date)               AS first_sale_date,
        EXTRACT(YEAR FROM AGE(MAX(f.order_date), MIN(f.order_date))) * 12
            + EXTRACT(MONTH FROM AGE(MAX(f.order_date), MIN(f.order_date))) AS lifespan_months
    FROM gold.dim_products p
    LEFT JOIN gold.fact_sales f ON p.product_key = f.product_key
    WHERE f.order_date IS NOT NULL
    GROUP BY p.product_key, p.product_id, p.product_name, p.category, p.subcategory, p.cost
)
SELECT 
    product_key,
    product_id,
    product_name,
    category,
    subcategory,
    cost,
    total_orders,
    total_sales,
    total_quantity,
    total_customers,
    lifespan_months,
    EXTRACT(YEAR FROM AGE(CURRENT_DATE, last_sale_date)) * 12
        + EXTRACT(MONTH FROM AGE(CURRENT_DATE, last_sale_date)) AS recency_months,
    ROUND(total_sales / NULLIF(total_orders, 0), 2) AS avg_order_revenue,
    ROUND(total_sales / NULLIF(lifespan_months, 0), 2) AS avg_monthly_revenue,
    CASE WHEN total_sales > 50000 THEN 'High-Performer'
         WHEN total_sales >= 10000 THEN 'Mid-Range'
         ELSE 'Low-Performer'
    END AS revenue_segment
FROM product_metrics;

-- ==============================================================================
-- Customer Report
-- Purpose: Consolidates key customer metrics and behaviors.
-- Highlights:
--   1. Customer details (name, gender, marital status, country)
--   2. Spending segmentation (High-Value, Mid-Value, Low-Value)
--   3. Aggregated metrics (orders, sales, quantity, products, lifespan)
--   4. KPIs (recency, average order revenue, average monthly revenue)
-- ==============================================================================
-- 4.2 rpt_customer_report
-- Comprehensive customer metrics and KPIs
-- Highlights:
--   • Customer details (name, gender, marital status, country)
--   • Spending segmentation (High-Value, Mid-Value, Low-Value)
--   • Aggregated metrics (orders, sales, quantity, products, lifespan)
--   • KPIs (recency, average order revenue, average monthly revenue)
-- -------------------------------------------------------------------------
DROP VIEW IF EXISTS gold.rpt_customer_report;
SELECT * FROM gold.rpt_customer_report;
CREATE VIEW gold.rpt_customer_report AS
WITH customer_metrics AS (
    SELECT 
        c.customer_id,
        c.customer_key,
        c.first_name,
        c.last_name,
        c.gender,
        c.marital_status,
        c.country,
        c.birth_date,
        COUNT(DISTINCT f.order_number)  AS total_orders,
        SUM(f.sales_amount)             AS total_sales,
        SUM(f.quantity)                  AS total_quantity,
        COUNT(DISTINCT f.product_key)   AS total_products,
        MAX(f.order_date)               AS last_order_date,
        MIN(f.order_date)               AS first_order_date,
        EXTRACT(YEAR FROM AGE(MAX(f.order_date), MIN(f.order_date))) * 12
            + EXTRACT(MONTH FROM AGE(MAX(f.order_date), MIN(f.order_date))) AS lifespan_months
    FROM gold.dim_customers c
    LEFT JOIN gold.fact_sales f ON c.customer_key = f.customer_key
    WHERE f.order_date IS NOT NULL
    GROUP BY c.customer_id, c.customer_key, c.first_name, c.last_name,
             c.gender, c.marital_status, c.country, c.birth_date
)
SELECT 
    customer_id,
    customer_key,
    first_name,
    last_name,
    gender,
    marital_status,
    country,
    birth_date,
    total_orders,
    total_sales,
    total_quantity,
    total_products,
    lifespan_months,

    EXTRACT(YEAR FROM AGE(CURRENT_DATE, last_order_date)) * 12
        + EXTRACT(MONTH FROM AGE(CURRENT_DATE, last_order_date)) AS recency_months,

    ROUND(total_sales / NULLIF(total_orders, 0), 2) AS avg_order_revenue,

    ROUND(total_sales / NULLIF(lifespan_months, 0), 2) AS avg_monthly_revenue,

    CASE WHEN total_sales > 5000 THEN 'High-Value'
         WHEN total_sales >= 1000 THEN 'Mid-Value'
         ELSE 'Low-Value'
    END AS spending_segment
FROM customer_metrics;
