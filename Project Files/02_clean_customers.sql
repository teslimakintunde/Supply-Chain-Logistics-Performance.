/*=========================================================
  PROJECT: Customer Data Cleaning
  OBJECTIVE
  Clean and standardize customer master data by correcting
  inconsistent categorical values, normalizing text fields,
  standardizing date formats, and preparing the dataset for
  business intelligence reporting and analytical modeling.

  SOURCE TABLE:
      customer_staging

  OUTPUT TABLE:
      clean_customers
=========================================================*/

/*=========================================================
 STEP 1: Create Clean Working Table

 Preserve the raw staging table by performing all cleaning
 operations in a separate table.
=========================================================*/

DROP TABLE IF EXISTS clean_customers;

CREATE TABLE clean_customers
LIKE customer_staging;

SELECT count(*)
FROM customer_staging;

SELECT * FROM clean_customers;

INSERT INTO clean_customers
SELECT *
FROM customer_staging;


/*=========================================================
 STEP 2: Initial Data Validation

 Verify record count after loading the working table.
=========================================================*/

SELECT COUNT(*) AS total_records
FROM clean_customers;


/*=========================================================
 STEP 3: Trim all text columns
=========================================================*/

UPDATE clean_customers
SET
    customer_id = TRIM(customer_id),
    full_name = TRIM(full_name),
    email = TRIM(email),
    phone_number = TRIM(phone_number),
    signup_date = TRIM(signup_date),
    gender = TRIM(gender),
    city = TRIM(city),
    region = TRIM(region),
    loyalty_tier = TRIM(loyalty_tier),
    preferred_payment = TRIM(preferred_payment),
    customer_segment = TRIM(customer_segment),
    acquisition_channel = TRIM(acquisition_channel),
    acquisition_campaign_id = TRIM(acquisition_campaign_id);

/*=========================================================
 STEP 4: Standardize Gender Values

 Resolve inconsistent spellings, abbreviations, and
 capitalization into standardized business values.
=========================================================*/

SELECT DISTINCT gender
FROM clean_customers;

UPDATE clean_customers
SET gender =
CASE
    WHEN LOWER(TRIM(gender)) IN ('female','femal','femle','f')
        THEN 'Female'

    WHEN LOWER(TRIM(gender)) IN ('male','m')
        THEN 'Male'

    ELSE gender
END;


/*=========================================================
 STEP 5: Standardize Loyalty Tier

 Correct inconsistent spellings and normalize loyalty
 program categories.
=========================================================*/

SELECT DISTINCT loyalty_tier
FROM clean_customers;

UPDATE clean_customers
SET loyalty_tier =
CASE

    WHEN LOWER(TRIM(loyalty_tier)) IN ('silver','silvr')
        THEN 'Silver'

    WHEN LOWER(TRIM(loyalty_tier)) IN ('gold','gld')
        THEN 'Gold'

    WHEN LOWER(TRIM(loyalty_tier)) IN ('platinum','platnum')
        THEN 'Platinum'

    WHEN LOWER(TRIM(loyalty_tier)) IN ('bronze','brnze')
        THEN 'Bronze'

    ELSE loyalty_tier

END;


/*=========================================================
 STEP 6: Standardize Preferred Payment Method

 Consolidate inconsistent payment method labels into
 standardized business-friendly values.
=========================================================*/

SELECT DISTINCT preferred_payment
FROM clean_customers;

UPDATE clean_customers
SET preferred_payment =
CASE
    WHEN LOWER(TRIM(preferred_payment)) IN ('creditcard','credit card') THEN 'Credit Card'
    WHEN LOWER(TRIM(preferred_payment)) IN ('paypal','pay pal') THEN 'Pay Pal'
    WHEN LOWER(TRIM(preferred_payment)) IN ('banktransfer','bank transfer') THEN 'Bank Transfer'
	WHEN LOWER(TRIM(preferred_payment)) IN ('debit card', "debitcard") THEN 'Debit Card'
    WHEN LOWER(TRIM(preferred_payment))='cash' THEN 'Cash'
    ELSE preferred_payment
END;


/*=========================================================
 STEP 7: Create Standardized Date Column

 Preserve the original signup_date while storing the
 converted DATE value separately.
=========================================================*/

ALTER TABLE clean_customers
ADD COLUMN signup_date_clean DATE;


/*=========================================================
  STEP 7: Correct Invalid Month Abbreviations
  Standardize month names that are not recognized by
  STR_TO_DATE().
=========================================================*/

UPDATE clean_customers
SET signup_date = REPLACE(signup_date,'Sept','Sep')
WHERE signup_date LIKE '%Sept%';


/*=========================================================
 STEP 8: Standardize Signup Dates

 Convert multiple source date formats into the MySQL DATE
 datatype using pattern recognition.
=========================================================*/

UPDATE clean_customers
SET signup_date_clean =
CASE
    /* ISO Date Format */
    WHEN signup_date REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
		THEN STR_TO_DATE(signup_date,'%Y-%m-%d')
        
    /* DD-Mon-YYYY */
    WHEN signup_date REGEXP '^[0-9]{2}-[A-Za-z]{3}-[0-9]{4}$'
        THEN STR_TO_DATE(signup_date,'%d-%b-%Y')
    /* DD-MM-YY */
    
      WHEN signup_date REGEXP '^[0-9]{2}-[A-Za-z]{3}-[0-9]{2}$'
        THEN STR_TO_DATE(signup_date,'%d-%b-%y')

    WHEN signup_date REGEXP '^[0-9]{2}-[0-9]{2}-[0-9]{2}$'
        THEN STR_TO_DATE(signup_date,'%d-%m-%y')

    /* DD/MM/YYYY */
    WHEN signup_date REGEXP '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}$'
         AND CAST(SUBSTRING_INDEX(signup_date,'/',1) AS UNSIGNED) > 12
         THEN STR_TO_DATE(signup_date,'%d/%m/%Y')

    /* MM/DD/YYYY */
    WHEN signup_date REGEXP '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}$'
         AND CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(signup_date,'/',2),'/',-1) AS UNSIGNED) > 12
		 THEN STR_TO_DATE(signup_date,'%m/%d/%Y')

    ELSE NULL

END;


/*=========================================================
 STEP 9: Correct Invalid Month Abbreviations

 Replace month names not recognized by STR_TO_DATE().
=========================================================*/

UPDATE clean_customers

SET signup_date = REPLACE(signup_date,'Sept','Sep')

WHERE signup_date LIKE '%Sept%';


/*=========================================================
 STEP 10: Reprocess Remaining Date Records

 Convert records that became valid after correcting
 month abbreviations.
=========================================================*/

UPDATE clean_customers
SET signup_date_clean =STR_TO_DATE(signup_date,'%d-%b-%Y')
WHERE signup_date_clean IS NULL
AND signup_date REGEXP '^[0-9]{1,2}-[A-Za-z]{3}-[0-9]{4}$';


/*=========================================================
 STEP 11: Post-Cleaning Validation

 Review any records that could not be converted into a
 valid DATE format.
=========================================================*/

SELECT
    signup_date,
    signup_date_clean
FROM clean_customers
WHERE signup_date_clean IS NULL;


/*=========================================================
 STEP 12: Final Quality Review

 Verify standardized categorical values and inspect the
 cleaned customer dataset.
=========================================================*/

SELECT DISTINCT customer_segment
FROM clean_customers;

SELECT *
FROM clean_customers;



SELECT
    customer_id,
    COUNT(*) AS total_rows
FROM clean_customers
GROUP BY customer_id
HAVING COUNT(*) > 1;

SELECT COUNT(*) AS total_rows
FROM clean_customers;

SELECT COUNT(DISTINCT customer_id) AS unique_customers
FROM clean_customers;


