
/*==============================================================================
 MODULE  : Customer Data Profiling
 DATABASE: MySQL 8.0+

 OBJECTIVE
   Assess customer data quality before cleansing and analytical modeling.

 DIMENSIONS
   1. Dataset volume
   2. Attribute completeness
   3. Categorical consistency
   4. Date-format consistency
   5. Domain validity
   6. Customer identifier uniqueness

 DESIGN PRINCIPLE
   Profiling is read-only. No source records are modified by this script.
==============================================================================*/


-- ============================================================================
-- 01. DATASET VOLUME
-- ============================================================================

SELECT
    COUNT(*) AS total_records,
    COUNT(DISTINCT customer_id) AS distinct_customer_ids,
    SUM(
        customer_id IS NULL
        OR TRIM(customer_id) = ''
    ) AS missing_customer_ids
FROM customer_staging;


-- ============================================================================
-- 02. CUSTOMER ATTRIBUTE COMPLETENESS
-- Blank strings and whitespace-only strings are treated as missing.
-- ============================================================================

SELECT
    COUNT(*) AS total_records,
    SUM(email IS NULL OR TRIM(email) = '') AS missing_email,
    ROUND(100.0 * SUM(email IS NULL OR TRIM(email) = '')/ NULLIF(COUNT(*), 0),2) AS missing_email_pct,
    SUM(phone_number IS NULL OR TRIM(phone_number) = '') AS missing_phone,
    ROUND(100.0 * SUM(phone_number IS NULL OR TRIM(phone_number) = '')/ NULLIF(COUNT(*), 0),2) AS missing_phone_pct,
    SUM(region IS NULL OR TRIM(region) = '') AS missing_region,
    ROUND(100.0 * SUM(region IS NULL OR TRIM(region) = '')/ NULLIF(COUNT(*), 0),2) AS missing_region_pct,
    SUM(signup_date IS NULL OR TRIM(signup_date) = '') AS missing_signup_date,
    SUM(loyalty_tier IS NULL OR TRIM(loyalty_tier) = '') AS missing_loyalty_tier
FROM customer_staging;


-- ============================================================================
-- 03. MISSING REGION EXCEPTIONS
-- Retrieve affected records for investigation.
-- ============================================================================

SELECT
    customer_id,city,region,acquisition_channel
FROM customer_staging
WHERE region IS NULL
   OR TRIM(region) = ''
ORDER BY customer_id;
-- ============================================================================
-- 04. CATEGORICAL DISTRIBUTION AND STANDARDIZATION
-- Compare raw values with trimmed, case-normalized values.
-- ============================================================================

-- Gender distribution
SELECT
    COALESCE(NULLIF(TRIM(gender), ''), '[MISSING]') AS gender_value,
    COUNT(*) AS customer_count,
    ROUND(100.0 * COUNT(*) / NULLIF((SELECT COUNT(*) FROM customer_staging), 0),2) AS percentage_of_customers
FROM customer_staging
GROUP BY COALESCE(NULLIF(TRIM(gender), ''), '[MISSING]')
ORDER BY customer_count DESC;


-- Loyalty tier distribution
SELECT
    COALESCE(
        NULLIF(LOWER(TRIM(loyalty_tier)), ''),
        '[MISSING]'
    ) AS normalized_loyalty_tier,
    COUNT(*) AS customer_count
FROM customer_staging
GROUP BY COALESCE(
    NULLIF(LOWER(TRIM(loyalty_tier)), ''),
    '[MISSING]'
)
ORDER BY customer_count DESC;


-- Preferred payment distribution
SELECT
    COALESCE(
        NULLIF(LOWER(TRIM(preferred_payment)), ''),
        '[MISSING]'
    ) AS normalized_payment_method,
    COUNT(*) AS customer_count
FROM customer_staging
GROUP BY COALESCE(
    NULLIF(LOWER(TRIM(preferred_payment)), ''),
    '[MISSING]'
)
ORDER BY customer_count DESC;


-- Acquisition channel distribution
SELECT
    COALESCE(
        NULLIF(LOWER(TRIM(acquisition_channel)), ''),
        '[MISSING]'
    ) AS normalized_acquisition_channel,
    COUNT(*) AS customer_count
FROM customer_staging
GROUP BY COALESCE(
    NULLIF(LOWER(TRIM(acquisition_channel)), ''),
    '[MISSING]'
)
ORDER BY customer_count DESC;


-- ============================================================================
-- 05. RAW CATEGORICAL VARIANTS
-- Identify different source spellings, casing and whitespace for review.
-- ============================================================================

SELECT
    LOWER(TRIM(gender)) AS normalized_value,
    COUNT(DISTINCT gender) AS raw_variant_count,
    GROUP_CONCAT(
        DISTINCT gender
        ORDER BY gender
        SEPARATOR ' | '
    ) AS raw_variants
FROM customer_staging
WHERE gender IS NOT NULL
  AND TRIM(gender) <> ''
GROUP BY LOWER(TRIM(gender))
HAVING COUNT(DISTINCT gender) > 1;


SELECT
    LOWER(TRIM(loyalty_tier)) AS normalized_value,
    COUNT(DISTINCT loyalty_tier) AS raw_variant_count,
    GROUP_CONCAT(
        DISTINCT loyalty_tier
        ORDER BY loyalty_tier
        SEPARATOR ' | '
    ) AS raw_variants
FROM customer_staging
WHERE loyalty_tier IS NOT NULL
  AND TRIM(loyalty_tier) <> ''
GROUP BY LOWER(TRIM(loyalty_tier))
HAVING COUNT(DISTINCT loyalty_tier) > 1;


-- ============================================================================
-- 06. SIGNUP DATE FORMAT PROFILING
-- Supported formats:
--   DD-MMM-YYYY : 14-Oct-2024
--   YYYY-MM-DD  : 2024-10-14
--   DD/MM/YYYY  : 14/10/2024
--
-- Format recognition is not the same as complete calendar-date validation.
-- Review the parsed values before standardizing the date column.
-- ============================================================================

SELECT
    CASE
        WHEN signup_date IS NULL OR TRIM(signup_date) = ''
            THEN 'MISSING'

        WHEN TRIM(signup_date) REGEXP
             '^[0-9]{2}-[A-Za-z]{3}-[0-9]{4}$'
            THEN 'DD-MMM-YYYY'

        WHEN TRIM(signup_date) REGEXP
             '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
            THEN 'YYYY-MM-DD'

        WHEN TRIM(signup_date) REGEXP
             '^[0-9]{2}/[0-9]{2}/[0-9]{4}$'
            THEN 'DD/MM/YYYY'

        ELSE 'UNRECOGNIZED'
    END AS detected_format,
    COUNT(*) AS record_count
FROM customer_staging
GROUP BY detected_format
ORDER BY record_count DESC;


-- Review date values that do not match a supported format.
SELECT
    customer_id,
    signup_date
FROM customer_staging
WHERE signup_date IS NOT NULL
  AND TRIM(signup_date) <> ''
  AND NOT (
      TRIM(signup_date) REGEXP
          '^[0-9]{2}-[A-Za-z]{3}-[0-9]{4}$'
      OR TRIM(signup_date) REGEXP
          '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
      OR TRIM(signup_date) REGEXP
          '^[0-9]{2}/[0-9]{2}/[0-9]{4}$'
  );


-- ============================================================================
-- 07. AGE DOMAIN VALIDATION
-- Identify negative or implausibly high ages and missing ages separately.
-- ============================================================================

SELECT
    SUM(age IS NULL) AS missing_age,
    SUM(age < 0 OR age > 120) AS invalid_age,
    SUM(age BETWEEN 0 AND 120) AS age_within_allowed_range
FROM customer_staging;


SELECT
    customer_id,
    age
FROM customer_staging
WHERE age < 0
   OR age > 120
ORDER BY age;


-- ============================================================================
-- 08. CUSTOMER KEY UNIQUENESS
-- Check duplicate identifiers and missing identifiers independently.
-- ============================================================================

SELECT
    customer_id,
    COUNT(*) AS record_count
FROM customer_staging
WHERE customer_id IS NOT NULL
  AND TRIM(customer_id) <> ''
GROUP BY customer_id
HAVING COUNT(*) > 1
ORDER BY record_count DESC;


-- Inspect records without a usable customer identifier.
SELECT *
FROM customer_staging
WHERE customer_id IS NULL
   OR TRIM(customer_id) = '';


-- ============================================================================
-- END OF CUSTOMER PROFILING
-- Document observed exceptions before implementing cleaning rules.
-- ============================================================================
