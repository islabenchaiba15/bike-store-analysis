-- ==============================================================================
-- SILVER LAYER: Schema Creation, Table Setup & Data Loading
-- This script runs as a single execution unit.
-- It creates the silver schema and tables, then loads cleaned data from bronze.
-- ==============================================================================

DO $$ 
BEGIN 

    -- =========================================================================
    -- SECTION 1: SCHEMA SETUP
    -- =========================================================================
    IF NOT EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'silver') THEN
        RAISE NOTICE 'Creating schema silver...';
        CREATE SCHEMA silver;
    END IF;

    -- =========================================================================
    -- SECTION 2: CREATE TABLES (DROP IF EXISTS)
    -- =========================================================================

    -- Table: crm_cust_info
    DROP TABLE IF EXISTS silver.crm_cust_info;
    RAISE NOTICE 'Creating table "silver.crm_cust_info"...';
    CREATE TABLE silver.crm_cust_info (
        cst_id INT,
        cst_key VARCHAR(20),
        cst_firstname VARCHAR(50),
        cst_lastname VARCHAR(50),
        cst_marital_status VARCHAR(50),
        cst_gndr VARCHAR(50),
        cst_create_date DATE,
        dwh_create_date TIMESTAMP DEFAULT NOW()
    );

    -- Table: crm_prd_info
    DROP TABLE IF EXISTS silver.crm_prd_info;
    RAISE NOTICE 'Creating table "silver.crm_prd_info"...';
    CREATE TABLE silver.crm_prd_info (
        prd_id INT,
        cat_id VARCHAR(50),
        prd_key VARCHAR(50),
        prd_nm VARCHAR(100),
        prd_cost NUMERIC(10,2),
        prd_line VARCHAR(100),
        prd_start_dt DATE,
        prd_end_dt DATE,
        dwh_create_date TIMESTAMP DEFAULT NOW()
    );

    -- Table: crm_sales_details
    DROP TABLE IF EXISTS silver.crm_sales_details;
    RAISE NOTICE 'Creating table "silver.crm_sales_details"...';
    CREATE TABLE silver.crm_sales_details (
        sls_ord_num VARCHAR(20),
        sls_prd_key VARCHAR(50),
        sls_cust_id INT,
        sls_order_dt DATE,
        sls_ship_dt DATE,
        sls_due_dt DATE,
        sls_sales NUMERIC(12,2),
        sls_quantity INT,
        sls_price NUMERIC(12,2),
        dwh_create_date TIMESTAMP DEFAULT NOW()
    );

    -- Table: erm_customers
    DROP TABLE IF EXISTS silver.erm_customers;
    RAISE NOTICE 'Creating table "silver.erm_customers"...';
    CREATE TABLE silver.erm_customers (
        cid VARCHAR(20),
        birth_date DATE,
        gender VARCHAR(10),
        dwh_create_date TIMESTAMP DEFAULT NOW()
    );

    -- Table: erm_customer_location
    DROP TABLE IF EXISTS silver.erm_customer_location;
    RAISE NOTICE 'Creating table "silver.erm_customer_location"...';
    CREATE TABLE silver.erm_customer_location (
        cid VARCHAR(20),
        country VARCHAR(50),
        dwh_create_date TIMESTAMP DEFAULT NOW()
    );

    -- Table: erm_product_category
    DROP TABLE IF EXISTS silver.erm_product_category;
    RAISE NOTICE 'Creating table "silver.erm_product_category"...';
    CREATE TABLE silver.erm_product_category (
        id VARCHAR(20),
        category VARCHAR(50),
        subcategory VARCHAR(100),
        maintenance VARCHAR(10),
        dwh_create_date TIMESTAMP DEFAULT NOW()
    );

    -- =========================================================================
    -- SECTION 3: LOAD CLEANED DATA (CRM)
    -- =========================================================================

    -- 3.1 crm_cust_info: deduplicate, trim names, standardize gender & marital status
    RAISE NOTICE 'Loading silver.crm_cust_info...';
    TRUNCATE TABLE silver.crm_cust_info;
    INSERT INTO silver.crm_cust_info (cst_id, cst_key, cst_firstname, cst_lastname, cst_marital_status, cst_gndr, cst_create_date)
    SELECT 
        cst_id,
        cst_key,
        TRIM(cst_firstname) AS cst_firstname,
        TRIM(cst_lastname) AS cst_lastname,
        CASE WHEN cst_marital_status = 'M' THEN 'Married'
             WHEN cst_marital_status = 'S' THEN 'Single'
             ELSE 'n/a'
        END AS cst_marital_status, 
        CASE WHEN cst_gndr = 'M' THEN 'Male'
             WHEN cst_gndr = 'F' THEN 'Female'
             ELSE 'n/a'
        END AS cst_gndr,
        cst_create_date
    FROM (
        SELECT *,
            ROW_NUMBER() OVER (PARTITION BY cst_id ORDER BY cst_create_date DESC) AS flag_last
        FROM bronze.crm_cust_info
        WHERE cst_id IS NOT NULL
    ) t
    WHERE flag_last = 1;

    -- 3.2 crm_prd_info: extract cat_id, standardize prd_line, fix end dates with LEAD
    RAISE NOTICE 'Loading silver.crm_prd_info...';
    TRUNCATE TABLE silver.crm_prd_info;
    INSERT INTO silver.crm_prd_info (prd_id, cat_id, prd_key, prd_nm, prd_cost, prd_line, prd_start_dt, prd_end_dt)
    SELECT 
        prd_id,
        REPLACE(SUBSTRING(prd_key, 1, 5), '-', '_') AS cat_id,
        SUBSTRING(prd_key, 7, LENGTH(prd_key)) AS prd_key,
        prd_nm,
        COALESCE(prd_cost, 0) AS prd_cost,
        CASE WHEN TRIM(prd_line) = 'R' THEN 'Road'
             WHEN TRIM(prd_line) = 'M' THEN 'Mountain'
             WHEN TRIM(prd_line) = 'S' THEN 'Sport'
             WHEN TRIM(prd_line) = 'T' THEN 'Touring'
             ELSE 'n/a'
        END AS prd_line,
        prd_start_dt,
        LEAD(prd_start_dt) OVER (PARTITION BY prd_key ORDER BY prd_start_dt) - 1 AS prd_end_dt
    FROM bronze.crm_prd_info;

    -- 3.3 crm_sales_details: convert int dates, fix negative sales/prices
    RAISE NOTICE 'Loading silver.crm_sales_details...';
    TRUNCATE TABLE silver.crm_sales_details;
    INSERT INTO silver.crm_sales_details (sls_ord_num, sls_prd_key, sls_cust_id, sls_order_dt, sls_ship_dt, sls_due_dt, sls_sales, sls_quantity, sls_price)
    SELECT 
        sls_ord_num,
        sls_prd_key,
        sls_cust_id,
        CASE WHEN sls_order_dt <= 0 OR LENGTH(sls_order_dt::TEXT) != 8 THEN NULL 
             ELSE TO_DATE(sls_order_dt::TEXT, 'YYYYMMDD') 
        END AS sls_order_dt,
        TO_DATE(sls_ship_dt::TEXT, 'YYYYMMDD') AS sls_ship_dt,
        TO_DATE(sls_due_dt::TEXT, 'YYYYMMDD') AS sls_due_dt,
        CASE WHEN sls_sales IS NULL OR sls_sales <= 0 OR sls_sales != ABS(sls_quantity) * ABS(sls_price)
             THEN ABS(sls_quantity) * ABS(sls_price)
             ELSE sls_sales 
        END AS sls_sales,
        sls_quantity,
        CASE WHEN sls_price IS NULL OR sls_price <= 0 
             THEN ABS(sls_sales) / NULLIF(sls_quantity, 0)
             ELSE ABS(sls_price) 
        END AS sls_price
    FROM bronze.crm_sales_details;

    -- =========================================================================
    -- SECTION 4: LOAD CLEANED DATA (ERP)
    -- =========================================================================

    -- 4.1 erm_customers: remove NAS prefix, fix future birth dates, standardize gender
    RAISE NOTICE 'Loading silver.erm_customers...';
    TRUNCATE TABLE silver.erm_customers;
    INSERT INTO silver.erm_customers (cid, birth_date, gender)
    SELECT 
        CASE WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4)
             ELSE cid
        END AS cid,
        CASE WHEN birth_date > CURRENT_DATE THEN NULL 
             ELSE birth_date 
        END AS birth_date,
        CASE WHEN UPPER(TRIM(gender)) = 'M' THEN 'Male'
             WHEN UPPER(TRIM(gender)) = 'F' THEN 'Female'
             WHEN UPPER(TRIM(gender)) = 'MALE' THEN 'Male'
             WHEN UPPER(TRIM(gender)) = 'FEMALE' THEN 'Female'
             ELSE 'n/a'
        END AS gender
    FROM bronze.erm_customers;

    -- 4.2 erm_customer_location: remove dash from cid, standardize country names
    RAISE NOTICE 'Loading silver.erm_customer_location...';
    TRUNCATE TABLE silver.erm_customer_location;
    INSERT INTO silver.erm_customer_location (cid, country)
    SELECT 
        REPLACE(cid, '-', '') AS cid,
        CASE WHEN TRIM(country) IN ('USA', 'US') THEN 'United States'
             WHEN TRIM(country) = 'DE' THEN 'Germany'
             WHEN country IS NULL OR TRIM(country) = '' THEN 'unknown'
             ELSE TRIM(country)
        END AS country
    FROM bronze.erm_customer_location;

    -- 4.3 erm_product_category: direct copy (data is clean)
    RAISE NOTICE 'Loading silver.erm_product_category...';
    TRUNCATE TABLE silver.erm_product_category;
    INSERT INTO silver.erm_product_category (id, category, subcategory, maintenance)
    SELECT 
        id,
        category,
        subcategory,
        maintenance
    FROM bronze.erm_product_category;

    RAISE NOTICE 'Silver layer loaded successfully!';

END $$;
