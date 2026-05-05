DO $$ 
BEGIN 
    -- Check and create schema 'bronze'
    IF NOT EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'bronze') THEN
        RAISE NOTICE 'Creating schema bronze...';
        CREATE SCHEMA bronze;
    END IF;

    -- Table: crm_cust_info
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'bronze' AND table_name = 'crm_cust_info') THEN
        RAISE NOTICE 'Table "bronze.crm_cust_info" already exists. Dropping it...';
        DROP TABLE bronze.crm_cust_info;
    END IF;
    RAISE NOTICE 'Creating table "bronze.crm_cust_info"...';
    CREATE TABLE bronze.crm_cust_info (
        cst_id INT,
        cst_key VARCHAR(20) ,
        cst_firstname VARCHAR(50),
        cst_lastname VARCHAR(50),
        cst_marital_status VARCHAR(50),
        cst_gndr VARCHAR(50),
        cst_create_date DATE
    );

    -- Table: crm_prd_info
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'bronze' AND table_name = 'crm_prd_info') THEN
        RAISE NOTICE 'Table "bronze.crm_prd_info" already exists. Dropping it...';
        DROP TABLE bronze.crm_prd_info;
    END IF;
    RAISE NOTICE 'Creating table "bronze.crm_prd_info"...';
    CREATE TABLE bronze.crm_prd_info (
        prd_id INT,
        prd_key VARCHAR(50) ,
        prd_nm VARCHAR(100),
        prd_cost NUMERIC(10,2),
        prd_line VARCHAR(100),
        prd_start_dt DATE,
        prd_end_dt DATE
    );

    -- Table: crm_sales_details
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'bronze' AND table_name = 'crm_sales_details') THEN
        RAISE NOTICE 'Table "bronze.crm_sales_details" already exists. Dropping it...';
        DROP TABLE bronze.crm_sales_details;
    END IF;
    RAISE NOTICE 'Creating table "bronze.crm_sales_details"...';
    CREATE TABLE bronze.crm_sales_details (
        sls_ord_num VARCHAR(20),
        sls_prd_key VARCHAR(50),
        sls_cust_id INT,
        sls_order_dt VARCHAR(20),
        sls_ship_dt VARCHAR(20),
        sls_due_dt VARCHAR(20),
        sls_sales NUMERIC(12,2),
        sls_quantity INT,
        sls_price NUMERIC(12,2)
    );

    -- Table: crm_customers
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'bronze' AND table_name = 'erm_customers') THEN
        RAISE NOTICE 'Table "bronze.erm_customers" already exists. Dropping it...';
        DROP TABLE bronze.erm_customers;
    END IF;
    RAISE NOTICE 'Creating table "bronze.erm_customers"...';
    CREATE TABLE bronze.erm_customers (
        cid VARCHAR(20),
        birth_date DATE,
        gender VARCHAR(10)
    );

    -- Table: crm_customer_location
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'bronze' AND table_name = 'erm_customer_location') THEN
        RAISE NOTICE 'Table "bronze.erm_customer_location" already exists. Dropping it...';
        DROP TABLE bronze.erm_customer_location;
    END IF;
    RAISE NOTICE 'Creating table "bronze.erm_customer_location"...';
    CREATE TABLE bronze.erm_customer_location (
        cid VARCHAR(20),
        country VARCHAR(50)
    );

    -- Table: crm_product_category
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'bronze' AND table_name = 'erm_product_category') THEN
        RAISE NOTICE 'Table "bronze.erm_product_category" already exists. Dropping it...';
        DROP TABLE bronze.erm_product_category;
    END IF;
    RAISE NOTICE 'Creating table "bronze.erm_product_category"...';
    CREATE TABLE bronze.erm_product_category (
        id VARCHAR(20),
        category VARCHAR(50),
        subcategory VARCHAR(100),
        maintenance VARCHAR(10)
    );

END $$;