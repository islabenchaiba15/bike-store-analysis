select 
EXTRACT(YEAR FROM order_date) as order_year,
EXTRACT(MONTH FROM order_date) as order_month,
sum(sales_amount) as total_sales,
COUNT(DISTINCT customer_key) as total_customers,
SUM(quantity) as total_quantity
from gold.fact_sales WHERE order_date is not null
GROUP BY order_year, order_month
ORDER BY order_year, order_month;

-- Cumulative total sales by year
SELECT 
    order_year,
    total_sales,
    SUM(total_sales) OVER (ORDER BY order_year) AS cumulative_sales
FROM (
    SELECT 
        EXTRACT(YEAR FROM order_date) AS order_year,
        SUM(sales_amount) AS total_sales
    FROM gold.fact_sales
    WHERE order_date IS NOT NULL
    GROUP BY EXTRACT(YEAR FROM order_date)
) yearly_sales
ORDER BY order_year;

WITH yearly_sales AS (
SELECT 
    EXTRACT(YEAR FROM order_date) AS order_year,
    p.product_name,
    SUM(f.sales_amount) AS total_revenue
FROM gold.fact_sales f
JOIN gold.dim_products p ON f.product_key = p.product_key
GROUP BY order_year, p.product_name
)
SELECT 
    order_year,
    product_name,
    total_revenue,
    ROUND(AVG(total_revenue) OVER (PARTITION BY product_name), 2) AS avg_revenue,
    total_revenue - ROUND(AVG(total_revenue) OVER (PARTITION BY product_name), 2) AS revenue_difference,
    CASE WHEN total_revenue > ROUND(AVG(total_revenue) OVER (PARTITION BY product_name), 2) THEN 'Above Average' 
        WHEN total_revenue < ROUND(AVG(total_revenue) OVER (PARTITION BY product_name), 2) THEN 'Below Average'
        ELSE 'Average'
    END AS revenue_status,
    LAG(total_revenue) OVER (PARTITION BY product_name ORDER BY order_year) AS prev_year_revenue,
    CASE WHEN total_revenue > LAG(total_revenue) OVER (PARTITION BY product_name ORDER BY order_year) THEN 'Increase'
    WHEN total_revenue < LAG(total_revenue) OVER (PARTITION BY product_name ORDER BY order_year) THEN 'Decrease'
    ELSE 'Stable'
    END AS revenue_trend
FROM yearly_sales
ORDER BY product_name, order_year;


SELECT product_name,
cost,
CASE WHEN cost > 500 THEN 'High'
WHEN cost < 100 THEN 'Low'
ELSE 'Medium'
END AS cost_category
from gold.dim_products;

WITH customer_sales AS (
SELECT 
customer_id,
SUM(sales_amount) AS toatal_spending,
MIN(order_date) AS first_order_date,
MAX(order_date) AS last_order_date,
DATE_PART('month', AGE(MAX(order_date), MIN(order_date))) AS total_months
FROM gold.fact_sales f
JOIN gold.dim_customers c ON f.customer_key = c.customer_key
WHERE order_date IS NOT NULL        -- ← add this line
GROUP BY customer_id
)
SELECT 
    customer_id,
    toatal_spending,
    first_order_date,
    last_order_date,
    total_months,
    CASE WHEN total_months >= 12 AND toatal_spending >= 3000 THEN 'VIP Customer'
        WHEN total_months < 12 AND toatal_spending < 3000 THEN 'Regular Customer'
        ELSE 'New Customer'
    END AS customer_type
FROM customer_sales
ORDER BY total_months DESC;

-- Count of customers per customer type
WITH customer_sales AS (
    SELECT 
        customer_id,
        SUM(sales_amount) AS toatal_spending,
        DATE_PART('month', AGE(MAX(order_date), MIN(order_date))) AS total_months
    FROM gold.fact_sales f
    JOIN gold.dim_customers c ON f.customer_key = c.customer_key
    WHERE order_date IS NOT NULL
    GROUP BY customer_id
),
customer_types AS (
    SELECT 
        customer_id,
        CASE WHEN total_months >= 12 AND toatal_spending >= 3000 THEN 'VIP Customer'
             WHEN total_months < 12 AND toatal_spending < 3000 THEN 'Regular Customer'
             ELSE 'New Customer'
        END AS customer_type
    FROM customer_sales
)
SELECT 
    customer_type,
    COUNT(*) AS total_customers
FROM customer_types
GROUP BY customer_type
ORDER BY total_customers DESC;

-- ==============================================================================
-- Product Report
-- Purpose: Consolidates key product metrics and behaviors.
-- Highlights:
--   1. Product details (name, category, subcategory, cost)
--   2. Revenue segmentation (High-Performer, Mid-Range, Low-Performer)
--   3. Aggregated metrics (orders, sales, quantity, customers, lifespan)
--   4. KPIs (recency, average order revenue, average monthly revenue)
-- ==============================================================================
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
FROM product_metrics
ORDER BY total_sales DESC;

-- ==============================================================================
-- Customer Report
-- Purpose: Consolidates key customer metrics and behaviors.
-- Highlights:
--   1. Customer details (name, gender, marital status, country)
--   2. Spending segmentation (High-Value, Mid-Value, Low-Value)
--   3. Aggregated metrics (orders, sales, quantity, products, lifespan)
--   4. KPIs (recency, average order revenue, average monthly revenue)
-- ==============================================================================
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
FROM customer_metrics
ORDER BY total_sales DESC;
