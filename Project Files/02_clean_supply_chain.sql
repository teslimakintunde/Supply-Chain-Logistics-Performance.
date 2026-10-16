
/*====================================================================
 PROJECT: Supply Chain Data Cleaning

 DOMAIN:
 Supply Chain Analytics

 OBJECTIVE:
 Prepare purchase order and supplier master data for
 inventory, procurement, warehouse and supplier
 performance analysis.

 DATA QUALITY ISSUES IDENTIFIED
 • Mixed date formats
 • Unsupported month abbreviations
 • Inconsistent delivery status values
 • Inconsistent payment terms
 • Missing derived logistics metrics
 • Incorrect quantity received values
 • Leading and trailing whitespace

 SOURCE TABLES
 • supply_chain_staging
 • suppliers_master_staging

 OUTPUT TABLES
 • clean_supply_chain
 • clean_suppliers_master
====================================================================*/
/*==============================================================
STEP 1 : Create Clean Working Table

Create a working copy of the staging table to preserve
raw source data and ensure all transformations are reproducible.
==============================================================*/

DROP TABLE IF EXISTS clean_suppliers_master;
DROP TABLE IF EXISTS clean_supply_chain;

SELECT * FROM supply_chain_staging;


CREATE TABLE clean_supply_chain
LIKE supply_chain_staging;

INSERT INTO clean_supply_chain
SELECT * FROM supply_chain_staging;

SELECT * FROM clean_supply_chain;

SELECT count(*) FROM clean_supply_chain;

SELECT order_date 
FROM clean_supply_chain;
/*==============================================================
STEP 2 : Remove Leading and Trailing Spaces

Standardize all text attributes before applying
categorical transformations.
==============================================================*/
UPDATE clean_supply_chain
SET
    po_id = TRIM(po_id),
    product_id = TRIM(product_id),
    category = TRIM(category),
    supplier_code = TRIM(supplier_code),
    supplier_country = TRIM(supplier_country),
    warehouse_id = TRIM(warehouse_id),
    warehouse_name = TRIM(warehouse_name),
    warehouse_region = TRIM(warehouse_region),
    order_date = TRIM(order_date),
    expected_arrival = TRIM(expected_arrival),
    actual_arrival = TRIM(actual_arrival),
    delivery_status = TRIM(delivery_status),
    payment_terms = TRIM(payment_terms),
    po_status = TRIM(po_status);
/*=========================================================
 STEP 3: Standardize Delivery Status

 Resolve spelling errors, capitalization differences,
 and inconsistent status values.
=========================================================*/

SELECT DISTINCT delivery_status 
FROM clean_supply_chain;

update clean_supply_chain
set delivery_status=
case
	when lower(trim(delivery_status)) in ("delayyed","delayed") then "Delayed"
    when lower(trim(delivery_status)) in ("delivered","deliverd") then "Delivered"
    WHEN LOWER(TRIM(delivery_status)) in ("cancelled","canceled") then "Cancelled"
    when lower(trim(delivery_status))="pending" then "Pending" 
    else delivery_status
end;
/*=========================================================
 STEP 4: Standardize payment_terms

 Resolve spelling errors, capitalization differences,
 and inconsistent status values.
=========================================================*/
SELECT DISTINCT payment_terms
FROM clean_supply_chain;

UPDATE clean_supply_chain
SET payment_terms=
CASE 
	WHEN LOWER(TRIM(payment_terms)) IN ("net 30", "net30") THEN "Net 30"
    WHEN LOWER(TRIM(payment_terms)) IN ("net 45", "net45") THEN "Net 45"
    WHEN LOWER(TRIM(payment_terms)) IN ("net 60", "net60") THEN "Net 60"
    WHEN LOWER(TRIM(payment_terms))="prepaid" THEN "Prepaid"
    WHEN LOWER(TRIM(payment_terms))="cod" THEN "Cod"
    ELSE payment_terms
end;


/*==============================================================
STEP 4 : Create Standardized Date Columns

Preserve the original date values while storing standardized
DATE data types separately.
==============================================================*/
alter table clean_supply_chain
add column order_date_clean date;

alter table clean_supply_chain
add column expected_arrival_clean date;

alter table clean_supply_chain
add column actual_arrival_clean date;



/*==============================================================
STEP 5 : Correct Unsupported Month Abbreviations

Replace unsupported month abbreviations before
date standardization.
==============================================================*/
UPDATE clean_supply_chain
SET
order_date = REPLACE(order_date,'Sept','Sep'),
expected_arrival = REPLACE(expected_arrival,'Sept','Sep'),
actual_arrival = REPLACE(actual_arrival,'Sept','Sep')
;

/*=============================================
  STEP 7: Standardize all date columns
=============================================*/

SELECT * FROM clean_supply_chain;
select order_date, order_date_clean
from clean_supply_chain;

UPDATE clean_supply_chain
SET order_date_clean=
CASE
    -- yyyy-mm-dd
    WHEN order_date REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
        THEN STR_TO_DATE(order_date,'%Y-%m-%d')

    -- dd-Mon-yyyy
    WHEN order_date REGEXP '^[0-9]{2}-[A-Za-z]{3}-[0-9]{4}$'
        THEN STR_TO_DATE(order_date,'%d-%b-%Y')
        
               -- ✅ FIX: DD-MMM-YY
    WHEN order_date REGEXP '^[0-9]{2}-[A-Za-z]{3}-[0-9]{2}$'
        THEN STR_TO_DATE(order_date,'%d-%b-%y')

    -- dd-mm-yy
    WHEN order_date REGEXP '^[0-9]{2}-[0-9]{2}-[0-9]{2}$'
        THEN STR_TO_DATE(order_date,'%d-%m-%y')

    -- slash dates where first number > 12
    WHEN order_date REGEXP '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}$'
         AND CAST(SUBSTRING_INDEX(order_date,'/',1) AS UNSIGNED) > 12
        THEN STR_TO_DATE(order_date,'%d/%m/%Y')

    -- slash dates where second number > 12
    WHEN order_date REGEXP '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}$'
         AND CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(order_date,'/',2),'/',-1) AS UNSIGNED) > 12
        THEN STR_TO_DATE(order_date,'%m/%d/%Y')

    ELSE NULL
END,
actual_arrival_clean=
CASE
    -- yyyy-mm-dd
    WHEN actual_arrival REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
        THEN STR_TO_DATE(actual_arrival,'%Y-%m-%d')

    -- dd-Mon-yyyy
    WHEN actual_arrival REGEXP '^[0-9]{2}-[A-Za-z]{3}-[0-9]{4}$'
        THEN STR_TO_DATE(actual_arrival,'%d-%b-%Y')
        
               -- ✅ FIX: DD-MMM-YY
    WHEN actual_arrival REGEXP '^[0-9]{2}-[A-Za-z]{3}-[0-9]{2}$'
        THEN STR_TO_DATE(actual_arrival,'%d-%b-%y')

    -- dd-mm-yy
    WHEN actual_arrival REGEXP '^[0-9]{2}-[0-9]{2}-[0-9]{2}$'
        THEN STR_TO_DATE(actual_arrival,'%d-%m-%y')

    -- slash dates where first number > 12
    WHEN actual_arrival REGEXP '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}$'
         AND CAST(SUBSTRING_INDEX(actual_arrival,'/',1) AS UNSIGNED) > 12
        THEN STR_TO_DATE(actual_arrival,'%d/%m/%Y')

    -- slash dates where second number > 12
    WHEN actual_arrival REGEXP '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}$'
         AND CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(actual_arrival,'/',2),'/',-1) AS UNSIGNED) > 12
        THEN STR_TO_DATE(actual_arrival,'%m/%d/%Y')

    ELSE NULL
END,
expected_arrival_clean=
CASE

    -- yyyy-mm-dd
    WHEN expected_arrival REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
        THEN STR_TO_DATE(expected_arrival,'%Y-%m-%d')

    -- dd-Mon-yyyy
    WHEN expected_arrival REGEXP '^[0-9]{2}-[A-Za-z]{3}-[0-9]{4}$'
        THEN STR_TO_DATE(expected_arrival,'%d-%b-%Y')
        
                       -- ✅ FIX: DD-MMM-YY
    WHEN expected_arrival REGEXP '^[0-9]{2}-[A-Za-z]{3}-[0-9]{2}$'
        THEN STR_TO_DATE(expected_arrival,'%d-%b-%y')

    -- dd-mm-yy
    WHEN expected_arrival REGEXP '^[0-9]{2}-[0-9]{2}-[0-9]{2}$'
        THEN STR_TO_DATE(expected_arrival,'%d-%m-%y')

    -- slash dates where first number > 12
    WHEN expected_arrival REGEXP '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}$'
         AND CAST(SUBSTRING_INDEX(expected_arrival,'/',1) AS UNSIGNED) > 12
        THEN STR_TO_DATE(expected_arrival,'%d/%m/%Y')

    -- slash dates where second number > 12
    WHEN expected_arrival REGEXP '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}$'
         AND CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(expected_arrival,'/',2),'/',-1) AS UNSIGNED) > 12
        THEN STR_TO_DATE(expected_arrival,'%m/%d/%Y')

    ELSE NULL
END;

SELECT order_date, order_date_clean
FROM clean_supply_chain
WHERE order_date_clean IS NULL;

SELECT actual_arrival, actual_arrival_clean
FROM clean_supply_chain
WHERE actual_arrival_clean IS NULL;

SELECT expected_arrival, expected_arrival_clean
FROM clean_supply_chain
WHERE expected_arrival_clean IS NULL;

/*=========================================================
STEP 5  Create Business Metrics
=========================================================*/
SELECT * FROM clean_supply_chain;

ALTER TABLE clean_supply_chain
ADD COLUMN actual_lead_time_days INT;

ALTER TABLE clean_supply_chain
ADD COLUMN delay_vs_expected_days INT;

ALTER TABLE clean_supply_chain
ADD column fill_rate_pct DECIMAL(5,2);

ALTER TABLE clean_supply_chain
ADD COLUMN defect_rate_pct DECIMAL(5,2);

/*=========================================================
STEP 6 Calculate KPI Columns
=========================================================*/
-- FIX quantity_received WHERE IT'S ZERO
UPDATE clean_supply_chain
SET quantity_received = quantity_ordered - quantity_defective
WHERE quantity_received = 0 
  AND quantity_ordered > 0
  AND quantity_defective <= quantity_ordered;
  
-- UPDATE THE NEW COLUMNS
UPDATE clean_supply_chain
SET actual_lead_time_days=DATEDIFF(actual_arrival_clean, order_date_clean);

UPDATE clean_supply_chain
SET delay_vs_expected_days=DATEDIFF(actual_arrival_clean, expected_arrival_clean);

UPDATE clean_supply_chain 
SET fill_rate_pct=(quantity_received /NULLIF(quantity_ordered,0))*100;

UPDATE clean_supply_chain
SET defect_rate_pct=(quantity_defective /NULLIF(quantity_received,0))*100;

SELECT * FROM clean_supply_chain;

SELECT quantity_received, quantity_ordered,quantity_defective,
fill_rate_pct,defect_rate_pct 
FROM clean_supply_chain;

SELECT quantity_received, quantity_ordered,quantity_defective
FROM clean_supply_chain;

SELECT quantity_received, quantity_defective,quantity_ordered
FROM clean_supply_chain 
WHERE quantity_defective > quantity_received;

/*==============================================================
STEP 5 : Correct Unsupported Month Abbreviations

Replace unsupported month abbreviations before
date standardization.
==============================================================*/
SELECT * FROM clean_supply_chain;

UPDATE clean_supply_chain
SET order_date=REPLACE(order_date,"Sept","Sep"),
	expected_arrival=REPLACE(expected_arrival,"Sept","Sep"),
    actual_arrival=REPLACE(actual_arrival,"Sept","Sep");
    

-- ------------------Supply Master Data ---------------------------------

/*==============================================================
STEP 1 : Create Clean Working Table

Create a working copy of the staging table to preserve
raw source data and ensure all transformations are reproducible.
==============================================================*/
SELECT * FROM suppliers_master_staging;

CREATE TABLE clean_suppliers_master
LIKE suppliers_master_staging;

SELECT * FROM clean_suppliers_master;

INSERT INTO clean_suppliers_master
SELECT * FROM suppliers_master_staging;

SELECT * FROM clean_suppliers_master;
/*==============================================================
STEP 3 : Remove Leading and Trailing Spaces

Standardize all text attributes before applying
categorical transformations.
==============================================================*/
UPDATE clean_suppliers_master
SET
    supplier_code = TRIM(supplier_code),
    supplier_name = TRIM(supplier_name),
    country = TRIM(country),
    reliability_tier = TRIM(reliability_tier),
    contract_start_date = TRIM(contract_start_date),
    preferred_supplier = TRIM(preferred_supplier),
    contact_email = TRIM(contact_email);
    
    
    
  
/*==============================================================
STEP 5 : Correct Unsupported Month Abbreviations

Replace unsupported month abbreviations before
date standardization.
==============================================================*/
UPDATE clean_suppliers_master
SET contract_start_date = REPLACE(contract_start_date,'Sept','Sep');
  
/*==============================================================
STEP 4 : Create Standardized Date Columns

Preserve the original date values while storing standardized
DATE data types separately.
==============================================================*/
alter table clean_suppliers_master
add column  clean_contract_start_date date;

select contract_start_date 
from clean_suppliers_master;
 
update clean_suppliers_master
set clean_contract_start_date=
CASE
    -- yyyy-mm-dd
    WHEN contract_start_date REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
        THEN STR_TO_DATE(contract_start_date,'%Y-%m-%d')

    -- dd-Mon-yyyy
    WHEN contract_start_date REGEXP '^[0-9]{2}-[A-Za-z]{3}-[0-9]{4}$'
        THEN STR_TO_DATE(contract_start_date,'%d-%b-%Y')
        
                             -- ✅ FIX: DD-MMM-YY
    WHEN contract_start_date REGEXP '^[0-9]{2}-[A-Za-z]{3}-[0-9]{2}$'
        THEN STR_TO_DATE(contract_start_date,'%d-%b-%y')


    -- dd-mm-yy
    WHEN contract_start_date REGEXP '^[0-9]{2}-[0-9]{2}-[0-9]{2}$'
        THEN STR_TO_DATE(contract_start_date,'%d-%m-%y')

    -- slash dates where first number > 12
    WHEN contract_start_date REGEXP '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}$'
         AND CAST(SUBSTRING_INDEX(contract_start_date,'/',1) AS UNSIGNED) > 12
        THEN STR_TO_DATE(contract_start_date,'%d/%m/%Y')

    -- slash dates where second number > 12
    WHEN contract_start_date REGEXP '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}$'
         AND CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(contract_start_date,'/',2),'/',-1) AS UNSIGNED) > 12
        THEN STR_TO_DATE(contract_start_date,'%m/%d/%Y')

    ELSE NULL
END;

UPDATE clean_suppliers_master
SET clean_contract_start_date = STR_TO_DATE(contract_start_date, '%d/%m/%Y')
WHERE clean_contract_start_date IS NULL
  AND contract_start_date REGEXP '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}$';

select contract_start_date,clean_contract_start_date 
from clean_suppliers_master
where clean_contract_start_date is null;

select count(*)
from clean_suppliers_master;
