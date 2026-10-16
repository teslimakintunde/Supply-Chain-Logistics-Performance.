
/*=========================================================
  PROJECT: Sales Data Cleaning
  OBJECTIVE
  Clean and standardize transactional sales data by
  correcting inconsistent categorical values, normalizing
  text fields, standardizing multiple date formats, and
  preparing the dataset for business intelligence reporting
  and sales performance analysis.

  SOURCE TABLE:
      sales_staging

  OUTPUT TABLE:
      clean_sales
=========================================================*/

/*=========================================================
 STEP 1: Create Clean Working Table

 Preserve the raw staging data by creating a working copy
 for all cleaning operations.
=========================================================*/

DROP TABLE IF EXISTS clean_sales;

CREATE TABLE clean_sales
LIKE sales_staging;

INSERT INTO clean_sales
SELECT *
FROM sales_staging;

SELECT * FROM clean_sales;

SELECT COUNT(*) FROM clean_sales;



/*=========================================================
 STEP 3: Remove Leading and Trailing Spaces

 Standardize text attributes to improve consistency and
 prevent duplicate categorical values.
=========================================================*/

UPDATE clean_sales
SET
    order_id = TRIM(order_id),
    customer_id = TRIM(customer_id),
    product_id = TRIM(product_id),
    order_date = TRIM(order_date),
    estimated_delivery = TRIM(estimated_delivery),
    actual_delivery = TRIM(actual_delivery),
    delivery_status = TRIM(delivery_status),
    payment_method = TRIM(payment_method),
    region = TRIM(region),
    return_requested = TRIM(return_requested),
    sales_channel = TRIM(sales_channel),
    notes = TRIM(notes),
    campaign_id = TRIM(campaign_id);
    
/*=========================================================
 STEP 4: Standardize Delivery Status

 Resolve spelling errors, capitalization differences,
 and inconsistent status values.
=========================================================*/

SELECT DISTINCT delivery_status
FROM clean_sales;

update clean_sales 
set delivery_status=
 case 
 	when lower(trim(delivery_status)) in ("deliverd","delivered") then "Delivered"
    when lower(trim(delivery_status)) in ("delayyed","delayed") then "Delayed"
    when lower(trim(delivery_status)) in ("cancelled","canceled") then "Cancelled"
    when lower(trim(delivery_status))="pending" then "Pending"
     when lower(trim(delivery_status))="processing" then "Processing"
    ELSE delivery_status
end;


/*=========================================================
 STEP 5: Standardize Payment Methods

 Consolidate multiple naming conventions into standardized
 business values.
=========================================================*/
SELECT DISTINCT payment_method
FROM clean_sales;

update clean_sales 
set payment_method=
CASE
    WHEN LOWER(TRIM(payment_method)) IN ('paypal','pay pal') THEN 'PayPal'
    WHEN LOWER(TRIM(payment_method)) IN ('credit card','creditcard') THEN 'Credit Card'
    WHEN LOWER(TRIM(payment_method)) IN ('bank transfer','banktransfer') THEN 'Bank Transfer'
     WHEN LOWER(TRIM(payment_method)) IN ('debit card', "debitcard") THEN 'Debit Card'
    WHEN LOWER(TRIM(payment_method)) = 'cash' THEN 'Cash'
   
    ELSE payment_method
END;


/*=========================================================
 STEP 6: Standardize Return Indicator
 Normalize Yes/No values for reporting consistency.
=========================================================*/

SELECT DISTINCT return_requested
FROM clean_sales;

update clean_sales 
set return_requested=
case
	when lower(trim(return_requested)) IN ("no", "n") then "No" 
    when lower(trim(return_requested)) IN ("yes","y") then "Yes"
    else return_requested
end;
/*=========================================================
 STEP 7: Create Standardized Date Columns

 Preserve the original text-based date columns while
 storing converted DATE values separately.
=========================================================*/

SELECT * FROM clean_sales;

ALTER TABLE clean_sales
ADD COLUMN order_date_clean DATE,
ADD COLUMN estimated_delivery_clean DATE,
ADD COLUMN actual_delivery_clean DATE;

/*=============================================
 STEP 8: Standardize unsupported month abbreviation
=============================================*/

UPDATE clean_sales
SET
    order_date = REPLACE(order_date,'Sept','Sep'),
    estimated_delivery = REPLACE(estimated_delivery,'Sept','Sep'),
    actual_delivery = REPLACE(actual_delivery,'Sept','Sep');
    
    

/*=============================================
  STEP 9: Standardize all date columns
=============================================*/

UPDATE clean_sales
SET
order_date_clean =
CASE
    WHEN order_date REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
        THEN STR_TO_DATE(order_date,'%Y-%m-%d')

    WHEN order_date REGEXP '^[0-9]{2}-[A-Za-z]{3}-[0-9]{4}$'
        THEN STR_TO_DATE(order_date,'%d-%b-%Y')
        
	  -- ✅ FIX: DD-MMM-YY
    WHEN order_date REGEXP '^[0-9]{2}-[A-Za-z]{3}-[0-9]{2}$'
        THEN STR_TO_DATE(order_date,'%d-%b-%y')

    WHEN order_date REGEXP '^[0-9]{2}-[0-9]{2}-[0-9]{2}$'
        THEN STR_TO_DATE(order_date,'%d-%m-%y')

    WHEN order_date REGEXP '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}$'
         AND CAST(SUBSTRING_INDEX(order_date,'/',1) AS UNSIGNED) > 12
        THEN STR_TO_DATE(order_date,'%d/%m/%Y')

    WHEN order_date REGEXP '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}$'
         AND CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(order_date,'/',2),'/',-1) AS UNSIGNED) > 12
        THEN STR_TO_DATE(order_date,'%m/%d/%Y')

    ELSE NULL
END,

estimated_delivery_clean =
CASE
    WHEN estimated_delivery REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
        THEN STR_TO_DATE(estimated_delivery,'%Y-%m-%d')

    WHEN estimated_delivery REGEXP '^[0-9]{2}-[A-Za-z]{3}-[0-9]{4}$'
        THEN STR_TO_DATE(estimated_delivery,'%d-%b-%Y')
        
           -- ✅ FIX: DD-MMM-YY
    WHEN estimated_delivery REGEXP '^[0-9]{2}-[A-Za-z]{3}-[0-9]{2}$'
        THEN STR_TO_DATE(estimated_delivery,'%d-%b-%y')

    WHEN estimated_delivery REGEXP '^[0-9]{2}-[0-9]{2}-[0-9]{2}$'
        THEN STR_TO_DATE(estimated_delivery,'%d-%m-%y')

    WHEN estimated_delivery REGEXP '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}$'
         AND CAST(SUBSTRING_INDEX(estimated_delivery,'/',1) AS UNSIGNED) > 12
        THEN STR_TO_DATE(estimated_delivery,'%d/%m/%Y')

    WHEN estimated_delivery REGEXP '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}$'
         AND CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(estimated_delivery,'/',2),'/',-1) AS UNSIGNED) > 12
        THEN STR_TO_DATE(estimated_delivery,'%m/%d/%Y')

    ELSE NULL
END,

actual_delivery_clean =
CASE
    WHEN actual_delivery REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
        THEN STR_TO_DATE(actual_delivery,'%Y-%m-%d')

    WHEN actual_delivery REGEXP '^[0-9]{2}-[A-Za-z]{3}-[0-9]{4}$'
        THEN STR_TO_DATE(actual_delivery,'%d-%b-%Y')
	
       -- ✅ FIX: DD-MMM-YY
    WHEN actual_delivery REGEXP '^[0-9]{2}-[A-Za-z]{3}-[0-9]{2}$'
        THEN STR_TO_DATE(actual_delivery,'%d-%b-%y')

    WHEN actual_delivery REGEXP '^[0-9]{2}-[0-9]{2}-[0-9]{2}$'
        THEN STR_TO_DATE(actual_delivery,'%d-%m-%y')

    WHEN actual_delivery REGEXP '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}$'
         AND CAST(SUBSTRING_INDEX(actual_delivery,'/',1) AS UNSIGNED) > 12
        THEN STR_TO_DATE(actual_delivery,'%d/%m/%Y')

    WHEN actual_delivery REGEXP '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}$'
         AND CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(actual_delivery,'/',2),'/',-1) AS UNSIGNED) > 12
        THEN STR_TO_DATE(actual_delivery,'%m/%d/%Y')

    ELSE NULL
END;

/*=============================================
 STEP 10: Validate failed conversions
=============================================*/

SELECT estimated_delivery,estimated_delivery_clean 
FROM clean_sales
WHERE estimated_delivery_clean IS NULL;

SELECT actual_delivery,actual_delivery_clean 
FROM clean_sales
WHERE actual_delivery_clean IS NULL;

SELECT order_date,order_date_clean 
FROM clean_sales
WHERE order_date_clean IS NULL;


SELECT
    order_date,
    order_date_clean,
    estimated_delivery,
    estimated_delivery_clean,
    actual_delivery,
    actual_delivery_clean
FROM clean_sales
WHERE order_date_clean IS NULL
   OR estimated_delivery_clean IS NULL
   OR actual_delivery_clean IS NULL;
   
/*=========================================================
 STEP 11: Final Data Quality Review

 Review cleaned transactional data before proceeding to
 exploratory analysis and dashboard development.
=========================================================*/

SELECT *
FROM clean_sales;

select count(*)
from clean_sales;





ALTER TABLE clean_sales
    ADD COLUMN gross_revenue DECIMAL(12,2) NULL,
    ADD COLUMN net_revenue   DECIMAL(12,2) NULL,
    ADD COLUMN cogs          DECIMAL(12,2) NULL,
    ADD COLUMN net_profit    DECIMAL(12,2) NULL;

-- Step 2: populate gross_revenue, net_revenue, cogs
UPDATE clean_sales
SET
    gross_revenue = ROUND(quantity * unit_price, 2),

    net_revenue = ROUND(
        CASE
            WHEN delivery_status <> 'Cancelled' AND return_requested <> 'Yes'
            THEN quantity * unit_price * (1 - COALESCE(discount_applied, 0))
            ELSE 0
        END, 2
    ),

    cogs = ROUND(
        CASE
            WHEN delivery_status <> 'Cancelled' AND return_requested <> 'Yes'
            THEN quantity * unit_cost
            ELSE 0
        END, 2
    );

-- Step 3: net_profit depends on the two columns just written, so it runs after
UPDATE clean_sales
SET net_profit = ROUND(net_revenue - cogs, 2);

SELECT * FROM clean_sales;











