-- ========================================
-- DATASET OVERVIEW
-- ========================================

-- Preview the raw data
SELECT *
FROM product_staging;

-- Total number of records
SELECT COUNT(*) AS total_rows
FROM product_staging;


-- ========================================
-- MISSING VALUE ASSESSMENT
-- ========================================

SELECT
    COUNT(*) AS total_rows,
    SUM(product_name IS NULL OR product_name = '') AS missing_product_name,
    SUM(category IS NULL OR category = '') AS missing_category,
    SUM(supplier_code IS NULL OR supplier_code = '') AS missing_supplier_code,
    SUM(country_of_origin IS NULL OR country_of_origin = '') AS missing_country,
    SUM(launch_date IS NULL OR launch_date = '') AS missing_launch_date
FROM product_staging;




-- ========================================
-- DUPLICATE RECORD CHECK
-- ========================================

SELECT
    product_id,
    COUNT(*) AS duplicate_count
FROM product_staging
GROUP BY product_id
HAVING COUNT(*) > 1;


-- ========================================
-- CATEGORICAL VALUE ASSESSMENT
-- ========================================

SELECT category, COUNT(*)
FROM product_staging
GROUP BY category;

SELECT is_active, COUNT(*)
FROM product_staging
GROUP BY is_active;


-- ========================================
-- BUSINESS RULE VALIDATION
-- ========================================

-- Products selling below cost

SELECT *
FROM product_staging
WHERE base_price < unit_cost;

-- Invalid prices

SELECT *
FROM product_staging
WHERE base_price <= 0
   OR unit_cost <= 0;


-- ========================================
-- DATE QUALITY ASSESSMENT
-- ========================================

SELECT launch_date
FROM product_staging
WHERE launch_date LIKE '%/%'
   OR launch_date LIKE '%-%';



-- ========================================
-- OUTLIER DETECTION
-- ========================================

SELECT *
FROM product_staging
WHERE base_price >
(
    SELECT AVG(base_price) + 3 * STDDEV(base_price)
    FROM product_staging
);