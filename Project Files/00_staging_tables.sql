/*==============================================================================
 PROJECT :Marketing-Channel-Performance
 MODULE  : Raw Data Ingestion / Staging Layer
 DIALECT : MySQL 8.0+
 PURPOSE :
   1. Establish consistent landing tables for six business source domains.
   2. Preserve source values for downstream validation and transformation.
   3. Provide a documented foundation for analytics-ready data models.

 DESIGN PRINCIPLES :
   - Staging is a landing layer, not the final analytical model.
   - Source identifiers are retained as business-key candidates.
   - Date fields remain VARCHAR until formats are validated and standardized.
   - No uniqueness assumptions are enforced before source profiling.
   - Destructive table replacement is intended for controlled development
     environments only; remove DROP statements in production deployments.
==============================================================================*/



-- ============================================================================
-- 01. CUSTOMER STAGING
-- Business domain: Customer acquisition, segmentation and loyalty
-- ============================================================================
DROP TABLE IF EXISTS customer_staging;
CREATE TABLE customer_staging (
    customer_id VARCHAR(20),
    full_name VARCHAR(100),
    email VARCHAR(100),
    phone_number VARCHAR(30),
    signup_date VARCHAR(20),
    gender VARCHAR(20),
    city VARCHAR(50),
    region VARCHAR(50),
    loyalty_tier VARCHAR(20),
    preferred_payment VARCHAR(50),
    age INT,
    customer_segment VARCHAR(50),
    acquisition_channel	VARCHAR(50),
    acquisition_campaign_id VARCHAR(20)
);

SELECT  * FROM customer_staging;
SELECT count(*)
FROM customer_staging;

DROP TABLE IF EXISTS sales_staging;


-- ============================================================================
-- 02. SALES STAGING
-- Business domain: Transactions, profitability and order fulfillment
-- ============================================================================

create table sales_staging
(
 order_id VARCHAR(20),
 customer_id VARCHAR(20),
 product_id VARCHAR(20),
 quantity INT,
 unit_price DECIMAL(10,2),
 unit_cost DECIMAL(10,2),
 order_date VARCHAR(20),
 estimated_delivery VARCHAR(20),
 actual_delivery VARCHAR(20),
 delivery_status VARCHAR(50),
 payment_method VARCHAR(50),
 region VARCHAR(50),
 discount_applied VARCHAR(10),
 shipping_cost DECIMAL(10,2),
 return_requested VARCHAR(10),
 sales_channel VARCHAR(50),
 notes TEXT,
 campaign_id VARCHAR(20)
);

SELECT * FROM sales_staging;

-- ============================================================================
-- 03. PRODUCT STAGING
-- Business domain: Product economics, inventory and replenishment
-- ============================================================================
DROP TABLE IF EXISTS product_staging;
CREATE TABLE product_staging (
    product_id VARCHAR(20),
    product_name VARCHAR(100),
    category VARCHAR(50),
    launch_date VARCHAR(20),
    base_price DECIMAL(10,2),
    unit_cost DECIMAL(10,2),
    supplier_code VARCHAR(20),
    country_of_origin VARCHAR(50),
    is_active VARCHAR(10),
    reorder_level INT,
    weight_kg DECIMAL(10,2),
    current_stock_level INT,
    seasonal_demand_pattern VARCHAR(100)
);

SELECT * FROM product_staging;
SELECT count(*) FROM product_staging;


-- loading advertising data
-- ============================================================================
-- 04. MARKETING CAMPAIGN STAGING
-- Business domain: Paid media, conversion and marketing return on investment
-- ============================================================================

DROP TABLE IF EXISTS marketing_campaigns_staging;
CREATE TABLE marketing_campaigns_staging (
    campaign_id VARCHAR(10),
    campaign_name VARCHAR(255),
    channel VARCHAR(50),
    channel_type VARCHAR(50),
    objective VARCHAR(50),
    target_region VARCHAR(50),
    target_category VARCHAR(100),
    featured_product_id VARCHAR(20),
    start_date VARCHAR(20),
    end_date VARCHAR(20),
    duration_days INT,
    budget DECIMAL(12,2),
    amount_spent DECIMAL(12,2),
    impressions INT,
    clicks INT,
    ctr_pct DECIMAL(6,3),
    conversions INT,
    conversion_rate_pct DECIMAL(6,2),
    cost_per_click DECIMAL(10,2),
    cost_per_acquisition DECIMAL(10,2),
    attributed_revenue DECIMAL(12,2),
    roas DECIMAL(6,2),
    campaign_status VARCHAR(50),
    managed_by VARCHAR(100)
);
SELECT * FROM marketing_campaigns_staging;


-- ============================================================================
-- 05. SUPPLIER MASTER STAGING
-- Business domain: Supplier governance and procurement reference data
-- ============================================================================

DROP TABLE IF EXISTS suppliers_master_staging;
create table suppliers_master_staging
(
supplier_code VARCHAR(10),
supplier_name VARCHAR(100),
country VARCHAR(50),
reliability_tier VARCHAR(20),
contract_start_date varchar(20),
preferred_supplier VARCHAR(5),
contact_email VARCHAR(100)
);

SELECT * FROM suppliers_master_staging;


-- ============================================================================
-- 06. SUPPLY CHAIN STAGING
-- Business domain: Purchase orders, inbound logistics and quality control
-- ============================================================================
DROP TABLE IF EXISTS supply_chain_staging;
CREATE TABLE supply_chain_staging (
    po_id VARCHAR(15),
    product_id VARCHAR(10),
    category VARCHAR(50),
    supplier_code VARCHAR(10),
    supplier_country VARCHAR(50),
    warehouse_id VARCHAR(10),
    warehouse_name VARCHAR(100),
    warehouse_region VARCHAR(50),
    order_date varchar(20),
    expected_arrival varchar(20),
    actual_arrival varchar(20),
    lead_time_days_planned INT,
    delivery_status VARCHAR(50),
    quantity_ordered INT,
    quantity_received INT,
    quantity_defective INT,
    unit_purchase_cost DECIMAL(10,2),
    total_po_value DECIMAL(12,2),
    freight_cost DECIMAL(10,2),
    payment_terms VARCHAR(50),
    po_status VARCHAR(50)
);

SELECT * FROM supply_chain_staging;


















