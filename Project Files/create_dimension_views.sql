/*==============================================================================
 MODULE  : Dimensional Data Modeling — Dimension Views
 FILE    : create_dimension_views.sql

 BUSINESS OBJECTIVE :
   Establish a consistent analytical foundation for evaluating sales revenue,
   customer behavior, product performance, marketing effectiveness, supplier
   reliability and warehouse operations.

 PURPOSE :
   Create reusable dimension views that organize descriptive business
   attributes into logical entities. These dimensions provide the context
   required to filter, group and compare performance measures across the
   commercial and operational areas of the business.

 DIMENSION INVENTORY :
   1. dim_customer  — Customer profiles, demographics, loyalty and age buckets.
   2. dim_product   — Product categories, pricing, cost and inventory attributes.
   3. dim_campaign  — Campaign characteristics, marketing channels and objectives.
   4. dim_supplier  — Supplier profiles, country and reliability attributes.
   5. dim_warehouse — Warehouse identity, location and regional attributes.
   6. dim_region    — Standardized regional keys for cross-domain analysis.

 DATA MODELING PRINCIPLES :
   - Separate descriptive attributes from transactional measures.
   - Standardize regional identifiers to support consistent regional reporting.
   - Apply consistent business definitions for derived attributes such as age
     buckets, while preserving the underlying customer attributes.
   - Design dimensions to support clear relationships with relevant fact views.
   - Validate dimension keys for NULL values and duplicates before establishing
     one-to-many relationships in Power BI.

 QUALITY & GOVERNANCE :
   - Dimension views reference the existing cleaned datasets.
   - Source data is not modified by these view definitions.
   - Column names and cleaning transformations must match the actual schemas.
   - Any assumptions about uniqueness, missing values or business classifications
     must be validated before being used in executive reporting.

 EXPECTED BUSINESS VALUE :
   Provide a reliable descriptive layer for customer segmentation, product
   profitability analysis, campaign comparisons, supplier evaluation and
   regional performance reporting.

=============================================================================*/


-- ============================================================================
-- 01. CUSTOMER DIMENSION — dim_customer
-- Purpose: Support customer segmentation, demographic analysis, loyalty
-- analysis and age-based comparisons of purchasing behavior.
-- ============================================================================
SELECT * FROM clean_customers;
CREATE OR REPLACE VIEW dim_customer AS
SELECT
    customer_id,
    full_name,
    email,
    phone_number,
    signup_date_clean,
    gender,
    city,
    region,
    loyalty_tier,
    preferred_payment,
    age,
CASE
	WHEN age IS NULL THEN 'Unknown'
	WHEN age < 18 THEN 'Under 18'
	WHEN age BETWEEN 18 AND 24 THEN '18-24'
	WHEN age BETWEEN 25 AND 34 THEN '25-34'
	WHEN age BETWEEN 35 AND 44 THEN '35-44'
	WHEN age BETWEEN 45 AND 54 THEN '45-54'
	WHEN age BETWEEN 55 AND 64 THEN '55-64'
	ELSE '65+'
END AS age_bucket,
CASE
    WHEN age IS NULL THEN 0
	WHEN age < 18 THEN 1
	WHEN age BETWEEN 18 AND 24 THEN 2
	WHEN age BETWEEN 25 AND 34 THEN 3
	WHEN age BETWEEN 35 AND 44 THEN 4
	WHEN age BETWEEN 45 AND 54 THEN 5
	WHEN age BETWEEN 55 AND 64 THEN 6
	ELSE 7
END AS age_bucket_sort,
    customer_segment,
    acquisition_channel,
    acquisition_campaign_id
FROM clean_customers;


-- ============================================================================
-- 02. PRODUCT DIMENSION — dim_product
-- Purpose: Provide product-level context for revenue, profitability, pricing,
-- category performance and inventory analysis.
-- ============================================================================
SELECT * FROM clean_products;
CREATE OR REPLACE VIEW dim_product AS
SELECT
    product_id,
    product_name,
    category,
    launch_date_clean,
    base_price,
    unit_cost,
    supplier_code,
    country_of_origin,
    is_active,
    reorder_level,
    weight_kg,
    current_stock_level,
    seasonal_demand_pattern
FROM clean_products;


-- ============================================================================
-- 03. CAMPAIGN DIMENSION — dim_campaign
-- Purpose: Describe campaigns by channel, objective, target market, featured
-- product and campaign attributes for marketing performance analysis.
-- ============================================================================
SELECT * FROM clean_marketing_campaigns;
CREATE OR REPLACE VIEW dim_campaign AS
SELECT
    campaign_id,
    campaign_name,
    channel,
    channel_type,
    objective,
    target_region,
    target_category,
    featured_product_id,
    start_date_clean,
    end_date_clean,
    duration_days,
    campaign_status,
    managed_by
FROM clean_marketing_campaigns;

-- ============================================================================
-- 04. SUPPLIER DIMENSION — dim_supplier
-- Purpose: Support supplier comparisons using supplier identity, geography,
-- reliability classifications and preferred-supplier attributes.
-- ============================================================================
SELECT * FROM clean_suppliers_master;
CREATE OR REPLACE VIEW dim_supplier AS
SELECT
    supplier_code,
    supplier_name,
    country,
    reliability_tier,
    clean_contract_start_date AS contract_start_date,
    preferred_supplier,
    contact_email
FROM clean_suppliers_master;

-- ============================================================================
-- 05. WAREHOUSE DIMENSION — dim_warehouse
-- Purpose: Provide warehouse and regional context for evaluating fulfillment,
-- delivery performance and operational differences across locations.
-- ============================================================================
SELECT * FROM clean_supply_chain;
CREATE OR REPLACE VIEW dim_warehouse AS
SELECT DISTINCT
    warehouse_id,
    warehouse_name,
    warehouse_region,
    UPPER(TRIM(warehouse_region)) AS region_key
FROM clean_supply_chain
WHERE warehouse_id IS NOT NULL;

-- ============================================================================
-- 06. REGION DIMENSION — dim_region
-- Purpose: Establish normalized regional identifiers to reduce inconsistencies
-- caused by differences in capitalization, spacing or source-system formatting.
-- ============================================================================
CREATE OR REPLACE VIEW dim_region AS
SELECT DISTINCT region_key
FROM (
    SELECT UPPER(TRIM(region)) AS region_key FROM clean_sales WHERE region IS NOT NULL
    UNION
    SELECT UPPER(TRIM(warehouse_region)) AS region_key FROM clean_supply_chain WHERE warehouse_region IS NOT NULL
) all_regions
WHERE region_key IS NOT NULL;

-- ============================================================================
-- 07. DIMENSION VALIDATION
-- Purpose: Verify key completeness and uniqueness before dimensions are used
-- on the one-side of analytical relationships.
-- ============================================================================