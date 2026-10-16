/*==============================================================================
 PROJECT : Marketing-Channel-Performance
 MODULE  : CSV Ingestion into MySQL Staging Layer
 ENGINE  : MySQL 8.0+

 PURPOSE
   Load six source datasets into their corresponding staging tables.

 INGESTION CONTRACT
   - CSV files contain one header row.
   - Fields are comma-delimited and double-quote enclosed.
   - Files use Windows CRLF line endings.
   - Blank values in selected nullable numeric columns become SQL NULL.
   - Source data is loaded into staging before cleaning and transformation.

 OPERATIONAL NOTE
   This script appends records unless staging tables are cleared first.
   For a complete reload, use the optional TRUNCATE block after verifying
   the target environment and confirming that a full refresh is intended.
==============================================================================*/


-- ============================================================================
-- 00. OPTIONAL FULL RELOAD
-- Uncomment ONLY when replacing the complete contents of all six staging
-- tables. TRUNCATE permanently removes the existing staging data.
-- ============================================================================

/*
TRUNCATE TABLE sales_staging;
TRUNCATE TABLE customer_staging;
TRUNCATE TABLE product_staging;
TRUNCATE TABLE marketing_campaigns_staging;
TRUNCATE TABLE suppliers_master_staging;
TRUNCATE TABLE supply_chain_staging;
*/



-- Load data for sales_staging

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/sales_data.csv'
INTO TABLE sales_staging
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(
order_id,
customer_id,
product_id,
quantity,
unit_price,
unit_cost,
order_date,
estimated_delivery,
actual_delivery,
delivery_status,
payment_method,
region,
discount_applied,
@shipping_cost,
return_requested,
sales_channel,
notes,
campaign_id
)
set shipping_cost=nullif(@shipping_cost,'');

select * from sales_staging;
select count(*) from sales_staging;

-- Load data for customer_staging

load data infile 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/customers_data.csv'
into table customer_staging
fields terminated by ','
enclosed by '"'
lines terminated by '\n'
ignore 1 rows
(
customer_id,
full_name,
email,
phone_number,
signup_date,
gender,
city,
region,
loyalty_tier,
preferred_payment,
@age,
customer_segment,
acquisition_channel,
acquisition_campaign_id
)
set age=nullif(@age,'');

SELECT * FROM customer_staging;
SELECT COUNT(*) FROM customer_staging;
-- Load data for Product_staing

load data infile 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/products_data.csv'
into table product_staging
fields terminated by ','
enclosed by '"'
lines terminated by '\n'
ignore 1 rows 
(
product_id,
product_name,
category,
launch_date,
base_price,
unit_cost,
supplier_code,
country_of_origin,
is_active,
reorder_level,
weight_kg,
current_stock_level,
seasonal_demand_pattern
);

select * from product_staging;
select count(*) from product_staging;



load data infile 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/advertising_data.csv'
into table marketing_campaigns_staging
fields terminated by ','
enclosed by '"'
lines terminated by '\n'
ignore 1 rows
(
campaign_id,
campaign_name,
channel,
channel_type,
objective,
target_region,
target_category,
featured_product_id,
start_date,
end_date,
duration_days,
budget,
amount_spent,
impressions,
clicks,
ctr_pct,
conversions,
conversion_rate_pct,
cost_per_click,
cost_per_acquisition,
attributed_revenue,
roas,
campaign_status,
managed_by
);

select * from marketing_campaigns_staging;

select * from marketing_campaigns_staging;
select count(*) from marketing_campaigns_staging;


load data infile 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/suppliers_master_data.csv'
into table  suppliers_master_staging
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS 
(
supplier_code,
supplier_name,
country,
reliability_tier,
contract_start_date,
preferred_supplier,
contact_email
);

select * from suppliers_master_staging;
SELECT COUNT(*) FROM suppliers_master_staging;


load data infile 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/supply_chain.csv'
into table supply_chain_staging
fields terminated by ','
enclosed by '"'
lines terminated by '\n'
ignore 1 rows
(
po_id,
product_id,
category,
supplier_code,
supplier_country,
warehouse_id,
warehouse_name,
warehouse_region,
order_date,
expected_arrival,
actual_arrival,
lead_time_days_planned,
delivery_status,
quantity_ordered,
quantity_received,
quantity_defective,
unit_purchase_cost,
total_po_value,
freight_cost,
payment_terms,
po_status
);


select * from supply_chain_staging;
select count(*) from supply_chain_staging;



