/*=========================================================
  PROJECT: Product Data Cleaning
  OBJECTIVE:
  Prepare the raw product dataset for downstream reporting,
  business intelligence, and analytical modeling by
  standardizing text fields, cleaning dates, and validating
  categorical values.
==========================================================*/


/*=========================================================
  STEP 1: Remove Existing Clean Table
  Drop the previous cleaned table to ensure the script is
  fully reproducible.
=========================================================*/

DROP TABLE IF EXISTS clean_products;


/*=========================================================
  STEP 2: Inspect Raw Dataset
=========================================================*/

SELECT *
FROM product_staging;

SELECT COUNT(*) AS total_records
FROM product_staging;


/*=========================================================
  STEP 3: Create Working Copy
  Preserve the raw staging table by performing all cleaning
  operations in a separate table.
=========================================================*/

CREATE TABLE clean_products
LIKE product_staging;

SELECT * FROM clean_products;

INSERT INTO clean_products
SELECT *
FROM product_staging;


/*=========================================================
  STEP 4: Add Standardized Date Column
  Preserve the original date column while storing the
  converted DATE value separately.
=========================================================*/

ALTER TABLE clean_products
ADD COLUMN launch_date_clean DATE;


/*=========================================================
  STEP 5: Remove Leading and Trailing Spaces
  Standardize text attributes to prevent duplicate values,
  inconsistent filtering, and inaccurate aggregations.
=========================================================*/

UPDATE clean_products
SET
    product_id = TRIM(product_id),
    product_name = TRIM(product_name),
    category = TRIM(category),
    launch_date = TRIM(launch_date),
    supplier_code = TRIM(supplier_code),
    country_of_origin = TRIM(country_of_origin),
    is_active = TRIM(is_active),
    seasonal_demand_pattern=TRIM(seasonal_demand_pattern);



/*=========================================================
  STEP 7: Correct Invalid Month Abbreviations
  Standardize month names that are not recognized by
  STR_TO_DATE().
=========================================================*/

UPDATE clean_products
SET launch_date = REPLACE(launch_date,'Sept','Sep')
WHERE launch_date LIKE '%Sept%';

/*=========================================================
  STEP 6: Standardize Launch Dates
  Convert multiple date formats into a single MySQL DATE
  format using pattern recognition and STR_TO_DATE().
=========================================================*/

UPDATE clean_products
SET launch_date_clean =
CASE

    /* ISO Format (YYYY-MM-DD) */
    WHEN launch_date REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
        THEN STR_TO_DATE(launch_date,'%Y-%m-%d')

    /* Format: DD-Mon-YYYY */
    WHEN launch_date REGEXP '^[0-9]{2}-[A-Za-z]{3}-[0-9]{4}$'
        THEN STR_TO_DATE(launch_date,'%d-%b-%Y')
        
	  -- ✅ FIX: DD-MMM-YY
    WHEN launch_date REGEXP '^[0-9]{2}-[A-Za-z]{3}-[0-9]{2}$'
        THEN STR_TO_DATE(launch_date,'%d-%b-%y')

    /* Format: DD-MM-YY */
    WHEN launch_date REGEXP '^[0-9]{2}-[0-9]{2}-[0-9]{2}$'
        THEN STR_TO_DATE(launch_date,'%d-%m-%y')

    /* Slash Dates (DD/MM/YYYY) */
    WHEN launch_date REGEXP '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}$'
         AND CAST(SUBSTRING_INDEX(launch_date,'/',1) AS UNSIGNED) > 12
        THEN STR_TO_DATE(launch_date,'%d/%m/%Y')

    /* Slash Dates (MM/DD/YYYY) */
    WHEN launch_date REGEXP '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}$'
         AND CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(launch_date,'/',2),'/',-1) AS UNSIGNED) > 12
        THEN STR_TO_DATE(launch_date,'%m/%d/%Y')

    ELSE NULL
END;

/*=========================================================
  STEP 8: Reprocess Remaining Invalid Dates
=========================================================*/

UPDATE clean_products
SET launch_date_clean = STR_TO_DATE(launch_date,'%d-%b-%Y')
WHERE launch_date_clean IS NULL
AND launch_date REGEXP '^[0-9]{1,2}-[A-Za-z]{3}-[0-9]{4}$';


/*=========================================================
  STEP 9: Data Quality Validation
  Identify records that failed date conversion for further
  investigation.
=========================================================*/

SELECT
    launch_date,
    launch_date_clean
FROM clean_products
WHERE launch_date_clean IS NULL;


/*=========================================================
  STEP 10: Validate Categorical Values
  Inspect categorical consistency before standardization.
=========================================================*/

SELECT DISTINCT is_active
FROM clean_products;

update clean_products 
set is_active=
case
	when lower(trim(is_active)) IN ("no", "n") then "No" 
    when lower(trim(is_active)) IN ("yes","y") then "Yes"
    else is_active
end;

/*=========================================================
  END OF PRODUCT DATA CLEANING
=========================================================*/



-- Check for duplicate product IDs
SELECT
    product_id,
    COUNT(*) AS duplicate_count
FROM clean_products
GROUP BY product_id
HAVING COUNT(*) > 1;

