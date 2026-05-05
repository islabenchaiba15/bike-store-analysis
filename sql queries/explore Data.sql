-- ==============================================================================
-- GOLD LAYER: Data Exploration & Analysis Queries
-- ==============================================================================

-- Preview all Gold layer tables
select * from gold.fact_sales;
select * from gold.dim_customers;
select * from gold.dim_products;

-- ==============================================================================
-- SECTION 1: Key Metrics (KPIs)
-- ==============================================================================

-- Date range of orders
select 
    min(order_date) as min_order_date,
    max(order_date) as max_order_date
from gold.fact_sales;

-- Total sales revenue
SELECT SUM(sales_amount) as total_sales
FROM gold.fact_sales;

-- Total quantity sold
SELECT SUM(quantity) as total_quantity
FROM gold.fact_sales;

-- Average unit price across all sales
SELECT AVG(unit_price) as avg_unit_price
FROM gold.fact_sales;

-- Number of unique customers who made purchases
SELECT COUNT(DISTINCT customer_key) as distinct_customers
FROM gold.fact_sales;

-- Number of unique products sold
SELECT COUNT(DISTINCT product_key) as distinct_products
FROM gold.fact_sales;

-- Number of unique orders placed
SELECT COUNT(DISTINCT order_number) as distinct_orders
FROM gold.fact_sales;

-- Total distinct customers (alternative)
SELECT count(DISTINCT customer_key) as total_order_number
FROM gold.fact_sales;

-- Combined KPI summary in a single result set
SELECT 'Total sales' as metric, SUM(sales_amount) as value
FROM gold.fact_sales
UNION ALL
SELECT 'Total quantity' as metric, SUM(quantity) as value
FROM gold.fact_sales
UNION ALL
SELECT 'Average unit price' as metric, AVG(unit_price) as value
FROM gold.fact_sales
UNION ALL
SELECT 'Distinct customers' as metric, COUNT(DISTINCT customer_key) as value
FROM gold.fact_sales
UNION ALL
SELECT 'Distinct products' as metric, COUNT(DISTINCT product_key) as value
FROM gold.fact_sales
UNION ALL
SELECT 'Distinct orders' as metric, COUNT(DISTINCT order_number) as value
FROM gold.fact_sales;

-- ==============================================================================
-- SECTION 2: Dimension Analysis
-- ==============================================================================

-- Customer distribution by country
SELECT country, count(DISTINCT customer_key) as total_customers
FROM gold.dim_customers
group by country;

-- Customer distribution by gender
select gender, count(DISTINCT customer_key) as total_customers
FROM gold.dim_customers
group by gender;

-- Product count per category
select category, count(DISTINCT product_key) as total_products
FROM gold.dim_products
group by category;

-- Average product cost per category (highest first)
select category, avg(cost) as avg_cost
FROM gold.dim_products
group by category
ORDER BY avg_cost desc;

-- ==============================================================================
-- SECTION 3: Revenue Analysis
-- ==============================================================================

-- Total sales by product category
select category, sum(f.sales_amount) as total_sales
FROM gold.fact_sales f
JOIN gold.dim_products p ON f.product_key = p.product_key
GROUP BY category
ORDER BY total_sales desc;

-- Revenue per customer (highest spenders first)
SELECT 
    c.customer_key,
    c.first_name,
    c.last_name,
    SUM(f.sales_amount) AS total_revenue
FROM gold.fact_sales f
JOIN gold.dim_customers c ON f.customer_key = c.customer_key
GROUP BY c.customer_key, c.first_name, c.last_name
ORDER BY total_revenue DESC;

-- Total quantity sold per country
SELECT 
    c.country,
    SUM(f.quantity) AS total_quantity
FROM gold.fact_sales f
JOIN gold.dim_customers c ON f.customer_key = c.customer_key
GROUP BY c.country
ORDER BY total_quantity DESC;

-- ==============================================================================
-- SECTION 4: Top & Bottom Products
-- ==============================================================================

-- Top 5 products by revenue
SELECT 
    p.product_name,
    SUM(f.sales_amount) AS total_revenue
FROM gold.fact_sales f
JOIN gold.dim_products p ON f.product_key = p.product_key
GROUP BY p.product_name
ORDER BY total_revenue DESC
LIMIT 5;

-- Bottom 5 products by revenue (lowest performers)
SELECT 
    p.product_name,
    SUM(f.sales_amount) AS total_revenue,
    ROW_NUMBER() OVER (ORDER BY SUM(f.sales_amount) ASC) AS row_num
FROM gold.fact_sales f
JOIN gold.dim_products p ON f.product_key = p.product_key
GROUP BY p.product_name
ORDER BY total_revenue ASC
LIMIT 5;
