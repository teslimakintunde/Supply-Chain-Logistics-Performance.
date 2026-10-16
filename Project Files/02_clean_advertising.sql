
/*=====================================================================
PROJECT: Marketing Campaign Data Cleaning
DOMAIN:
Marketing Analytics
OBJECTIVE:
Prepare raw marketing campaign data for business intelligence,
campaign performance reporting, ROI analysis, and dashboarding.

DATA QUALITY ISSUES IDENTIFIED

• Leading and trailing whitespace
• Mixed date formats
• Unsupported month abbreviations ("Sept")
• Inconsistent categorical values
• Text formatting inconsistencies

OUTPUT TABLE
clean_marketing_campaigns
=====================================================================*/

/*==============================================================
STEP 1 : Create Clean Working Table

Create a working copy of the staging table to preserve
raw source data and ensure all transformations are reproducible.
==============================================================*/

DROP TABLE IF EXISTS clean_marketing_campaigns;

CREATE TABLE clean_marketing_campaigns
LIKE marketing_campaigns_staging;

SELECT * FROM marketing_campaigns_staging;

INSERT INTO clean_marketing_campaigns
SELECT *
FROM marketing_campaigns_staging;

SELECT * FROM clean_marketing_campaigns;
/*==============================================================
STEP 3 : Remove Leading and Trailing Spaces

Standardize all text attributes before applying
categorical transformations.
==============================================================*/

UPDATE clean_marketing_campaigns
SET
campaign_id = TRIM(campaign_id),
campaign_name = TRIM(campaign_name),
channel = TRIM(channel),
channel_type = TRIM(channel_type),
objective = TRIM(objective),
target_region = TRIM(target_region),
target_category = TRIM(target_category),
featured_product_id = TRIM(featured_product_id),
campaign_status = TRIM(campaign_status),
managed_by = TRIM(managed_by),
start_date = TRIM(start_date),
end_date = TRIM(end_date);

/*==============================================================
STEP 4 : Create Standardized Date Columns

Preserve the original date values while storing standardized
DATE data types separately.
==============================================================*/
ALTER TABLE clean_marketing_campaigns
ADD COLUMN start_date_clean DATE,
ADD COLUMN end_date_clean DATE;

/*==============================================================
STEP 5 : Correct Unsupported Month Abbreviations

Replace unsupported month abbreviations before
date standardization.
==============================================================*/
UPDATE clean_marketing_campaigns
SET
start_date = REPLACE(start_date,'Sept','Sep'),
end_date = REPLACE(end_date,'Sept','Sep');
/*==============================================================
 STEP 6: Standardize Campaign Dates

 Convert multiple date formats into MySQL DATE values for both
 campaign start and end dates in a single transformation.
==============================================================*/

UPDATE clean_marketing_campaigns
SET
    start_date = REPLACE(start_date, 'Sept', 'Sep'),
    end_date = REPLACE(end_date, 'Sept', 'Sep');

/*=============================================
  STEP 7: Standardize all date columns
=============================================*/

UPDATE clean_marketing_campaigns
SET
start_date_clean =
CASE
    -- yyyy-mm-dd
    WHEN start_date REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
        THEN STR_TO_DATE(start_date,'%Y-%m-%d')

    -- dd-Mon-yyyy
    WHEN start_date REGEXP '^[0-9]{2}-[A-Za-z]{3}-[0-9]{4}$'
        THEN STR_TO_DATE(start_date,'%d-%b-%Y')
        
          -- ✅ FIX: DD-MMM-YY
    WHEN start_date REGEXP '^[0-9]{2}-[A-Za-z]{3}-[0-9]{2}$'
        THEN STR_TO_DATE(start_date,'%d-%b-%y')

    -- dd-mm-yy
    WHEN start_date REGEXP '^[0-9]{2}-[0-9]{2}-[0-9]{2}$'
        THEN STR_TO_DATE(start_date,'%d-%m-%y')

    -- dd/mm/yyyy
    WHEN start_date REGEXP '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}$'
         AND CAST(SUBSTRING_INDEX(start_date,'/',1) AS UNSIGNED) > 12
        THEN STR_TO_DATE(start_date,'%d/%m/%Y')

    -- mm/dd/yyyy
    WHEN start_date REGEXP '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}$'
         AND CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(start_date,'/',2),'/',-1) AS UNSIGNED) > 12
        THEN STR_TO_DATE(start_date,'%m/%d/%Y')

    ELSE NULL
END,

end_date_clean =
CASE
    -- yyyy-mm-dd
    WHEN end_date REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
        THEN STR_TO_DATE(end_date,'%Y-%m-%d')

    -- dd-Mon-yyyy
    WHEN end_date REGEXP '^[0-9]{2}-[A-Za-z]{3}-[0-9]{4}$'
        THEN STR_TO_DATE(end_date,'%d-%b-%Y')
        
          -- ✅ FIX: DD-MMM-YY
    WHEN end_date REGEXP '^[0-9]{2}-[A-Za-z]{3}-[0-9]{2}$'
        THEN STR_TO_DATE(end_date,'%d-%b-%y')

    -- dd-mm-yy
    WHEN end_date REGEXP '^[0-9]{2}-[0-9]{2}-[0-9]{2}$'
        THEN STR_TO_DATE(end_date,'%d-%m-%y')

    -- dd/mm/yyyy
    WHEN end_date REGEXP '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}$'
         AND CAST(SUBSTRING_INDEX(end_date,'/',1) AS UNSIGNED) > 12
        THEN STR_TO_DATE(end_date,'%d/%m/%Y')

    -- mm/dd/yyyy
    WHEN end_date REGEXP '^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}$'
         AND CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(end_date,'/',2),'/',-1) AS UNSIGNED) > 12
        THEN STR_TO_DATE(end_date,'%m/%d/%Y')

    ELSE NULL
END;


SELECT
    start_date,
    start_date_clean
FROM clean_marketing_campaigns
WHERE start_date_clean IS  NULL;

SELECT
    end_date,
    end_date_clean
FROM clean_marketing_campaigns
WHERE end_date_clean IS  NULL;

/*=============================================
  STEP 8: Validate records that failed conversion
=============================================*/
SELECT
    campaign_id,
    start_date,
    start_date_clean,
    end_date,
    end_date_clean
FROM clean_marketing_campaigns
WHERE start_date_clean IS NULL
   OR end_date_clean IS NULL;

/*=========================================================
 STEP 9: Final Data Quality Review

 Review cleaned transactional data before proceeding to
 exploratory analysis and dashboard development.
=========================================================*/

SELECT *
FROM clean_marketing_campaigns;

select count(*) from
clean_marketing_campaigns;
 