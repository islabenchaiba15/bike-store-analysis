copy bronze.crm_cust_info 
FROM 'C:\temp\sql-data-warehouse-project\datasets\source_crm\cust_info.csv' 
WITH (FORMAT csv, HEADER, DELIMITER ',');
  


select * from bronze.crm_prd_info;
select * from bronze.erm_product_category;