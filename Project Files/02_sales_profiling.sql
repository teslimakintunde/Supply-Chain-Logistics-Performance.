

-- View raw data
SELECT * FROM sales_staging;

-- Row count
SELECT COUNT(*) FROM sales_staging;


-- ========================================
-- DUPLICATE RECORD CHECK
-- ========================================
SELECT 
    order_id, 
    customer_id, 
    product_id, 
    quantity, 
    order_date, 
    COUNT(*) AS occurrence_count
FROM sales_staging
GROUP BY order_id, customer_id, product_id, quantity, order_date
HAVING COUNT(*) > 1;


-- COMPLETENESS CHECKS (Missing Values)


SELECT
    COUNT(*) AS total_rows,
    
    SUM(CASE WHEN quantity IS NULL THEN 1 ELSE 0 END) AS missing_quantity,
    SUM(CASE WHEN unit_price IS NULL THEN 1 ELSE 0 END) AS missing_unit_price,
    SUM(CASE WHEN unit_cost IS NULL THEN 1 ELSE 0 END) AS missing_unit_cost,
    
    SUM(CASE WHEN order_date IS NULL OR order_date = '' THEN 1 ELSE 0 END) AS missing_order_date,
    SUM(CASE WHEN estimated_delivery IS NULL OR estimated_delivery = '' THEN 1 ELSE 0 END) AS missing_estimated_delivery,
    SUM(CASE WHEN actual_delivery IS NULL OR actual_delivery = '' THEN 1 ELSE 0 END) AS missing_actual_delivery,
    
    SUM(CASE WHEN delivery_status IS NULL OR TRIM(delivery_status) = '' THEN 1 ELSE 0 END) AS missing_delivery_status,
    SUM(CASE WHEN payment_method IS NULL OR TRIM(payment_method) = '' THEN 1 ELSE 0 END) AS missing_payment_method,
    SUM(CASE WHEN return_requested IS NULL OR TRIM(return_requested) = '' THEN 1 ELSE 0 END) AS missing_return_requested,
    SUM(CASE WHEN notes IS NULL OR TRIM(notes) = '' THEN 1 ELSE 0 END) AS missing_notes

FROM sales_staging;


-- UNIQUENESS / DUPLICATE CHECK

-- Check full duplicate rows
SELECT *, COUNT(*) AS duplicate_count
FROM sales_staging
GROUP BY 
    quantity, unit_price, unit_cost, order_date, estimated_delivery,
    actual_delivery, delivery_status, payment_method, region,
    discount_applied, shipping_cost, return_requested, sales_channel, notes
HAVING COUNT(*) > 1;




-- 3. NUMERIC VALIDATION
SELECT *
FROM sales_staging
WHERE 
    quantity <= 0
    OR unit_price <= 0
    OR unit_cost <= 0
    OR shipping_cost < 0;

-- Negative Profit Detection
SELECT *,
       (unit_price - unit_cost) AS profit
FROM sales_staging
WHERE unit_price < unit_cost;


-- Discount Outliers
SELECT *
FROM sales_staging
WHERE discount_applied < 0 OR discount_applied > 1;

-- Shipping Cost Zero Check
SELECT *
FROM sales_staging
WHERE shipping_cost = 0;


-- DATE VALIDATION (CRITICAL)
-- Detect Mixed Formats 
-- The date column contains multiple formats (DD-MMM-YYYY, YYYY-MM-DD, DD/MM/YYYY)
SELECT order_date
FROM sales_staging
WHERE order_date LIKE '%-%'
   OR order_date LIKE '%/%';



-- Actual < Order Date
SELECT *
FROM sales_staging
WHERE 
    STR_TO_DATE(actual_delivery, '%d/%m/%Y') 
    < STR_TO_DATE(order_date, '%d/%m/%Y');


-- Delivery Delay Calculation
SELECT *,
       DATEDIFF(
           STR_TO_DATE(actual_delivery, '%d/%m/%Y'),
           STR_TO_DATE(estimated_delivery, '%d/%m/%Y')
       ) AS delay_days
FROM sales_staging
WHERE actual_delivery IS NOT NULL;



-- CATEGORICAL CONSISTENCY CHECKS
-- Delivery Status Variations
SELECT delivery_status, COUNT(*) AS count
FROM sales_staging
GROUP BY delivery_status
ORDER BY count DESC;


-- Detect Dirty Values (Trim + Case)
SELECT DISTINCT 
    delivery_status,
    TRIM(UPPER(delivery_status)) AS cleaned_status
FROM sales_staging;

-- Payment Method Variants
SELECT payment_method, COUNT(*) AS count
FROM sales_staging
GROUP BY payment_method
ORDER BY count DESC;


-- Return Requested Issues
SELECT return_requested, COUNT(*) AS count
FROM sales_staging
GROUP BY return_requested;


-- BUSINESS RULE VALIDATION
-- Cancelled Orders Should Not Have Delivery Dates
SELECT *
FROM sales_staging
WHERE 
    TRIM(UPPER(delivery_status)) LIKE '%CANCEL%'
    AND actual_delivery IS NOT NULL;


-- OUTLIER DETECTION
-- Price Outliers
SELECT *
FROM sales_staging
WHERE unit_price > (
    SELECT AVG(unit_price) + 3 * STDDEV(unit_price)
    FROM sales_staging
);


SELECT
    COUNT(*) AS total_rows,

    SUM(CASE WHEN unit_price < unit_cost THEN 1 ELSE 0 END) AS negative_profit_rows,

    SUM(CASE 
        WHEN TRIM(UPPER(delivery_status)) NOT IN ('DELIVERED','DELAYED','CANCELLED') 
        THEN 1 ELSE 0 
    END) AS invalid_status_rows,

    SUM(CASE 
        WHEN actual_delivery IS NULL OR actual_delivery = '' 
        THEN 1 ELSE 0 
    END) AS missing_delivery_rows

FROM sales_staging;



SELECT * FROM sales_staging;




