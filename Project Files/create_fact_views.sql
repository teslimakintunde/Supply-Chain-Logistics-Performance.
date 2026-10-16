/*==============================================================================
 MODULE  : Analytical Fact Views — Sales, Supply Chain, Customer & Marketing
 FILE    : create_fact_views.sql

 BUSINESS OBJECTIVE :
   Build a reusable analytical layer that supports the measurement of sales
   performance, customer value, marketing effectiveness and supply chain
   operations.

 PURPOSE :
   Transform cleaned transactional data into business-focused analytical
   views. Centralize recurring calculations and business classifications
   to ensure consistent metric definitions across downstream analysis and
   Power BI reports.

 ANALYTICAL VIEW INVENTORY :

   CORE BUSINESS FACT VIEWS
   1. fact_sales
      Sales-line measures, revenue, costs, profit, discounts and order
      attributes for commercial performance analysis.

   2. fact_supply_chain
      Procurement activity, purchase orders, delivery performance, quantities
      received, defective quantities and available operational measures.

   3. Fact_Campaign_Performance
      Campaign expenditure, marketing funnel metrics, attributed revenue,
      sales outcomes, customer acquisition costs and campaign performance.

   CUSTOMER ANALYTICAL VIEWS
   4. Fact_Customer_Base
      Customer purchasing behavior, financial performance, order history,
      operational indicators, lifecycle stages and reusable classifications.

   5. Fact_Customer_CLV
      Realized customer profitability, projected lifetime value, acquisition
      economics and customer health scoring.

   6. Fact_RFM_Segmentation
      Customer recency, purchase frequency, monetary value and behavioral
      segments for retention and customer prioritization.

   MARKETING ANALYTICS MART
   7. mart_marketing_attribution
      Campaign-level comparison of platform-attributed revenue and internal
      sales outcomes, marketing profitability, customer value and estimated
      campaign payback.

 ANALYTICAL DESIGN PRINCIPLES :
   - Define and preserve the grain of every analytical view.
   - Distinguish sales-line, order-level, customer-level, campaign-level and
     purchase-order-level measures.
   - Prevent double counting when order-level values repeat across sales lines.
   - Maintain consistent definitions for revenue, cost, profit and marketing
     performance metrics.
   - Reuse established customer calculations rather than duplicating business
     logic across downstream views.
   - Separate realized customer value from projected lifetime value.
   - Keep campaign attribution and internally recorded sales outcomes distinct.
   - Design the views to support consistent relationships with dimension views.

 DATA QUALITY & VALIDATION :
   - Verify business-key completeness and uniqueness at each declared grain.
   - Reconcile financial metrics against the cleaned source datasets.
   - Validate date calculations, scoring rules and division-by-zero handling.
   - Review joins for unintended duplication, missing records and row
     multiplication.
   - Confirm that all referenced columns exist in the cleaned source schemas.
   - Validate aggregation behavior before connecting the views to Power BI.

 EXPECTED BUSINESS VALUE :
   Enable decision-makers to investigate revenue and profitability drivers,
   assess procurement and fulfillment performance, evaluate campaign returns,
   understand customer lifetime value, identify retention opportunities and
   make more informed commercial decisions.

 EXECUTION NOTE :
   Create upstream views before downstream views that depend on them.
   Run validation queries after view creation to confirm that the resulting
   analytical data is complete and consistent.

==============================================================================*/


-- ============================================================================
-- 01. SALES FACT — fact_sales
-- Grain: Confirm whether one row represents a sales line or a complete order.
-- Purpose: Measure sales activity, revenue, costs, profit and discounts while
-- preserving the distinction between line-level and order-level metrics.
-- ============================================================================

CREATE OR REPLACE VIEW fact_sales AS
WITH sales_base AS (
    SELECT
        order_id,
        customer_id,
        product_id,
        campaign_id,

        order_date_clean,
        estimated_delivery_clean,
        actual_delivery_clean,

        quantity,
        unit_price,
        unit_cost,

        discount_applied,
        shipping_cost,

        gross_revenue,
        net_revenue,
        cogs,
        net_profit,

        delivery_status,
        payment_method,
        region,
        return_requested,
        sales_channel,
        notes,

        SUM(net_revenue) OVER (
            PARTITION BY order_id
        ) AS total_order_net_revenue

    FROM clean_sales
)
SELECT
    order_id,
    customer_id,
    product_id,
    campaign_id,
    order_date_clean,
    estimated_delivery_clean,
    actual_delivery_clean,
    quantity,
    unit_price,
    unit_cost,
    discount_applied,
    shipping_cost,
    gross_revenue,
    net_revenue,
    cogs,
    net_profit,
    total_order_net_revenue,
    CASE
        WHEN actual_delivery_clean IS NOT NULL
         AND order_date_clean IS NOT NULL
        THEN DATEDIFF(actual_delivery_clean,order_date_clean)
    END AS actual_delivery_days,

    delivery_status,
    payment_method,
    region,
    return_requested,
    sales_channel,
    notes,
    UPPER(TRIM(region)) AS region_key,  

    /* =========================================
       ORDER REVENUE BUCKET
       Based on TOTAL revenue per order
       ========================================= */
    CASE
        WHEN total_order_net_revenue <= 0 THEN 'Free / Refunded ($0)'
        WHEN total_order_net_revenue < 500 THEN 'Low Value (< $500)'
        WHEN total_order_net_revenue < 2000 THEN 'Standard Value ($500-$1,999)'
        WHEN total_order_net_revenue < 6000 THEN 'High Value ($2,000-$5,999)'
        ELSE 'Premium Value ($6,000+)'
    END AS order_revenue_bucket,
    CASE
        WHEN total_order_net_revenue <= 0 THEN 1
        WHEN total_order_net_revenue < 500 THEN 2
        WHEN total_order_net_revenue < 2000 THEN 3
        WHEN total_order_net_revenue < 6000 THEN 4
        ELSE 5
    END AS order_revenue_bucket_sort,
    /* =========================================
       PRODUCT UNIT PRICE TIER
       ========================================= */
    CASE
        WHEN unit_price < 20 THEN 'Budget'
        WHEN unit_price < 75 THEN 'Mid-Range'
        WHEN unit_price < 200 THEN 'Premium'
        ELSE 'Luxury'
    END AS unit_price_bucket,
    CASE
        WHEN unit_price < 20 THEN 1
        WHEN unit_price < 75 THEN 2
        WHEN unit_price < 200 THEN 3
        ELSE 4
    END AS unit_price_bucket_sort,
    /* =========================================
       DISCOUNT BUCKET
       ========================================= */
    CASE
        WHEN discount_applied = 0 THEN 'No Discount'
        WHEN discount_applied <= 0.05 THEN 'Low Discount (1-5%)'
        WHEN discount_applied <= 0.10 THEN 'Moderate Discount (6-10%)'
        WHEN discount_applied <= 0.15 THEN 'High Discount (11-15%)'
        ELSE 'Very High Discount (16%+)'
    END AS discount_bucket,
    CASE
        WHEN discount_applied = 0 THEN 1
        WHEN discount_applied <= 0.05 THEN 2
        WHEN discount_applied <= 0.10 THEN 3
        WHEN discount_applied <= 0.15 THEN 4
        ELSE 5
    END AS discount_bucket_sort
FROM sales_base;

-- ============================================================================
-- 02. SUPPLY CHAIN FACT — fact_supply_chain
-- Grain: Confirm whether one row represents a purchase order or purchase-order
-- line, based on the structure of the source data.
-- Purpose: Measure procurement activity, quantities, delivery outcomes,
-- received quantities, defective quantities and available operational metrics.
-- ============================================================================

CREATE OR REPLACE VIEW fact_supply_chain AS
SELECT
    po_id,
    product_id,
    supplier_code,
    warehouse_id,

    order_date_clean,
    expected_arrival_clean,
    actual_arrival_clean,

    lead_time_days_planned,
    actual_lead_time_days,
    delay_vs_expected_days,

    quantity_ordered,
    quantity_received,
    quantity_defective,

    fill_rate_pct,
    defect_rate_pct,

    unit_purchase_cost,
    total_po_value,
    freight_cost,

    payment_terms,
    po_status,
    delivery_status
FROM clean_supply_chain;
SELECT * FROM clean_supply_chain;

-- ============================================================================
-- 03. CAMPAIGN PERFORMANCE — Fact_Campaign_Performance
-- Grain: One row per campaign, subject to campaign_id uniqueness.
-- Purpose: Combine campaign investment and funnel metrics with sales outcomes,
-- customer acquisition measures and campaign performance classifications.
-- ============================================================================

CREATE OR REPLACE VIEW Fact_Campaign_Performance AS
WITH sales_summary AS
(
SELECT
		campaign_id,
		COUNT(DISTINCT order_id) AS total_orders,
		COUNT(DISTINCT customer_id) AS purchasing_customers,
		COUNT(DISTINCT product_id) AS products_sold,
		SUM(quantity) AS total_units,
    
     -- Revenue calculations using pre-calculated columns
        ROUND(SUM(gross_revenue), 2) AS total_revenue,
        ROUND(SUM(net_revenue), 2) AS total_net_revenue,
        ROUND(SUM(cogs), 2) AS total_cost,
        ROUND(SUM(net_profit), 2) AS net_profit,
         -- Average calculations using pre-calculated columns
        ROUND(SUM(net_revenue)/ NULLIF(COUNT(DISTINCT order_id), 0),2) AS average_order_value,
       
        ROUND(AVG(discount_applied) * 100, 2) AS average_discount_pct,
        ROUND(AVG(shipping_cost), 2) AS average_shipping_cost,
        ROUND(AVG(DATEDIFF(actual_delivery_clean, order_date_clean)), 2) AS average_delivery_days,
        
        -- Return and delivery metrics
        ROUND(COUNT(DISTINCT CASE WHEN LOWER(TRIM(return_requested)) = 'yes' THEN order_id END)/
        NULLIF(COUNT(DISTINCT order_id), 0) * 100,2) AS return_rate_pct,
        ROUND(
       COUNT(DISTINCT CASE WHEN LOWER(TRIM(delivery_status)) = 'delivered' THEN order_id END)/ NULLIF(COUNT(DISTINCT order_id), 0)
       * 100,2 ) AS delivery_rate_pct
FROM clean_sales
GROUP BY campaign_id),
customer_summary AS
(
SELECT acquisition_campaign_id AS campaign_id,
    COUNT(DISTINCT customer_id) AS acquired_customers
    FROM clean_customers
	GROUP BY acquisition_campaign_id
)
SELECT m.campaign_id,m.start_date_clean, m.duration_days,
YEAR(m.start_date_clean) AS campaign_year,
QUARTER(m.start_date_clean) AS campaign_quarter,
MONTH(m.start_date_clean) AS campaign_month,
ROUND(m.budget,2) AS campaign_budget,
ROUND(m.amount_spent,2) AS marketing_spend,
m.impressions, m.clicks, m.conversions,

ROUND(m.attributed_revenue,2) AS attributed_revenue,
ROUND(m.amount_spent/NULLIF(m.clicks,0),2) AS actual_cpc,
ROUND(m.amount_spent/NULLIF(m.conversions,0),2) AS actual_cpa,
ROUND(m.amount_spent/NULLIF(m.impressions,0)*1000,2) AS cpm,
ROUND(m.clicks/NULLIF(m.impressions,0)*100,2) AS ctr_pct,
ROUND(m.conversions/NULLIF(m.clicks,0)*100,2) AS conversion_rate_pct,
ROUND(m.attributed_revenue/NULLIF(m.amount_spent,0),2) AS roas,
COALESCE(s.total_orders,0) AS total_orders,
COALESCE(c.acquired_customers,0) AS total_customers_acquired,
COALESCE(s.products_sold,0) AS products_sold,
COALESCE(s.total_units,0) AS units_sold,
COALESCE(s.total_revenue,0) AS total_sales_revenue,
COALESCE(s.total_cost,0) AS total_sales_cost,
COALESCE(s.net_profit,0) AS net_profit,
COALESCE(s.average_order_value,0) AS average_order_value,
COALESCE(s.average_discount_pct,0) AS average_discount_pct,
COALESCE(s.average_shipping_cost,0) AS average_shipping_cost,
COALESCE(s.return_rate_pct,0) AS return_rate_pct,
COALESCE(s.delivery_rate_pct,0) AS delivery_rate_pct,
COALESCE(s.average_delivery_days,0) AS average_delivery_days,
ROUND(COALESCE(s.net_profit,0)-m.amount_spent,2) AS marketing_profit,
ROUND((COALESCE(s.net_profit,0)-m.amount_spent)/NULLIF(m.amount_spent,0)*100,2) AS marketing_roi_pct,
ROUND(m.amount_spent/NULLIF(c.acquired_customers,0),2) AS cac,
CASE 
	WHEN COALESCE(s.net_profit,0)-m.amount_spent>0 AND m.attributed_revenue / NULLIF(m.amount_spent, 0) >=5 THEN 'Excellent'
	WHEN m.attributed_revenue / NULLIF(m.amount_spent, 0) >=3 THEN 'High Performing'
	WHEN m.attributed_revenue / NULLIF(m.amount_spent, 0) >=2 THEN 'Good'
	WHEN m.attributed_revenue / NULLIF(m.amount_spent, 0) =1 THEN 'Average'
	ELSE 'Poor'
END AS performance_rating
FROM clean_marketing_campaigns m
LEFT JOIN sales_summary s
ON m.campaign_id=s.campaign_id
LEFT JOIN customer_summary c
ON m.campaign_id=c.campaign_id;

-- ============================================================================
-- 04. CUSTOMER ANALYTICAL BASE — Fact_Customer_Base
-- Grain: One row per customer.
-- Purpose: Centralize customer purchasing behavior, financial performance,
-- operational indicators, order history and reusable customer classifications.
-- ============================================================================
CREATE OR REPLACE VIEW Fact_Customer_Base AS
/* ==============================================================
   FACT CUSTOMER BASE
   ==============================================================

   Grain:
   One row per customer

   Purpose:
   - Central customer analytical layer
   - Prevents repeated business logic across CLV, RFM,
     customer segmentation and marketing analysis
   - Provides reusable customer financial, behavioral,
     operational and lifecycle metrics

   Downstream consumers:
   - Fact_Customer_CLV
   - Fact_RFM_Segmentation
   - Customer dashboards
   - Marketing attribution
   - Customer profitability analysis
   ============================================================== */
WITH dataset_date AS
(
    SELECT
        MAX(order_date_clean) AS dataset_max_date
    FROM clean_sales
),
customer_sales AS
(
    /* ==========================================================
       CUSTOMER SALES AGGREGATION

       Grain:
       One row per customer

       IMPORTANT:
       Order-level metrics use COUNT(DISTINCT order_id)
       because clean_sales is at order-product grain.
       ========================================================== */
    SELECT
        s.customer_id,
        /* ------------------------------------------------------
           ORDER / PURCHASE BEHAVIOR
           ------------------------------------------------------ */
        COUNT(DISTINCT s.order_id) AS total_orders,
        MIN(s.order_date_clean) AS first_order_date,
        MAX(s.order_date_clean) AS last_order_date,
        COALESCE(SUM(s.quantity), 0) AS total_units,
        COUNT(DISTINCT s.product_id) AS unique_products_purchased,
        /* ------------------------------------------------------
           FINANCIAL PERFORMANCE
           ------------------------------------------------------ */
        ROUND(SUM(COALESCE(s.gross_revenue, 0)), 2) AS gross_revenue,
        ROUND(SUM(COALESCE(s.net_revenue, 0)), 2) AS net_revenue,
        ROUND(SUM(COALESCE(s.cogs, 0)), 2) AS total_cost,
        ROUND(SUM(COALESCE(s.net_profit, 0)), 2) AS net_profit,
        /* ------------------------------------------------------
           CUSTOMER ECONOMICS
           ------------------------------------------------------ */
        ROUND(SUM(COALESCE(s.gross_revenue, 0) * COALESCE(s.discount_applied, 0)),2) AS total_discount_given,
        ROUND(SUM(COALESCE(s.shipping_cost, 0)),2) AS total_shipping_cost,
        /* ------------------------------------------------------
           AOV

           Correct because one order can contain multiple
           product rows.
           ------------------------------------------------------ */
        ROUND(SUM(COALESCE(s.net_revenue, 0))/ NULLIF(COUNT(DISTINCT s.order_id), 0),2) AS average_order_value,
        /* ------------------------------------------------------
           PROFITABILITY
           ------------------------------------------------------ */
        ROUND(SUM(COALESCE(s.net_profit, 0))/ NULLIF(SUM(COALESCE(s.net_revenue, 0)), 0)* 100,2) AS profit_margin_pct,
        /* ------------------------------------------------------
           DISCOUNT / SHIPPING BEHAVIOR
           ------------------------------------------------------ */
        ROUND(AVG(COALESCE(s.discount_applied, 0)) * 100,2) AS average_discount_pct,
        ROUND(AVG(COALESCE(s.shipping_cost, 0)),2) AS average_shipping_cost,
        /* ------------------------------------------------------
           DELIVERY PERFORMANCE
           ------------------------------------------------------ */
        ROUND(AVG(
                CASE
                    WHEN s.actual_delivery_clean IS NOT NULL 
                    AND s.order_date_clean IS NOT NULL
                    THEN DATEDIFF(s.actual_delivery_clean, s.order_date_clean)
                END
            ),2) AS average_delivery_days,
        /* ------------------------------------------------------
           ORDER STATUS

           DISTINCT order_id prevents multi-product orders
           from being counted more than once.
           ------------------------------------------------------ */
        COUNT(DISTINCT CASE WHEN LOWER(TRIM(s.delivery_status)) = 'cancelled'
                THEN s.order_id END) AS cancelled_orders,
        COUNT(DISTINCT CASE WHEN LOWER(TRIM(s.delivery_status)) = 'delayed'
                THEN s.order_id END) AS delayed_orders,
        COUNT(DISTINCT CASE WHEN LOWER(TRIM(s.return_requested)) = 'yes'
                THEN s.order_id END) AS returned_orders,
        /* ------------------------------------------------------
           SALES CHANNEL BEHAVIOR
           ------------------------------------------------------ */
        COUNT(DISTINCT CASE WHEN LOWER(TRIM(s.sales_channel)) = 'online'
                THEN s.order_id END) AS online_orders,
        COUNT(DISTINCT CASE WHEN LOWER(TRIM(s.sales_channel)) = 'in-store'
                THEN s.order_id END) AS instore_orders,
        COUNT(DISTINCT CASE WHEN LOWER(TRIM(s.sales_channel)) = 'mobile app'
                THEN s.order_id END) AS mobile_orders,
        COUNT(DISTINCT CASE WHEN LOWER(TRIM(s.sales_channel)) = 'phone'
                THEN s.order_id END) AS phone_orders,
        COUNT(DISTINCT CASE WHEN LOWER(TRIM(s.sales_channel)) = 'reseller'
                THEN s.order_id END) AS reseller_orders
    FROM clean_sales s
    GROUP BY
        s.customer_id
)
SELECT
    /* ==========================================================
       CUSTOMER IDENTIFICATION
       ========================================================== */
    c.customer_id,
    c.signup_date_clean,
    c.acquisition_campaign_id,
    d.dataset_max_date,
    /* ==========================================================
       CORE CUSTOMER METRICS
       ========================================================== */
    COALESCE(cs.total_orders, 0) AS total_orders,
    cs.first_order_date,
    cs.last_order_date,
    COALESCE(cs.total_units, 0) AS total_units,
    COALESCE(cs.unique_products_purchased, 0) AS unique_products_purchased,
    /* ==========================================================
       FINANCIAL METRICS
       ========================================================== */
    COALESCE(cs.gross_revenue, 0) AS gross_revenue,
    COALESCE(cs.net_revenue, 0) AS net_revenue,
    COALESCE(cs.total_cost, 0) AS total_cost,
    COALESCE(cs.net_profit, 0) AS net_profit,
    COALESCE(cs.total_discount_given, 0) AS total_discount_given,
    COALESCE(cs.total_shipping_cost, 0) AS total_shipping_cost,
    /* ==========================================================
       DERIVED CUSTOMER ECONOMICS
       ========================================================== */
    COALESCE(cs.average_order_value, 0) AS average_order_value,
    COALESCE(cs.profit_margin_pct, 0) AS profit_margin_pct,
    COALESCE(cs.average_discount_pct, 0) AS average_discount_pct,
    COALESCE(cs.average_shipping_cost, 0) AS average_shipping_cost,
    COALESCE(cs.average_delivery_days, 0) AS average_delivery_days,
    /* ==========================================================
       ORDER STATUS
       ========================================================== */
    COALESCE(cs.cancelled_orders, 0) AS cancelled_orders,
    COALESCE(cs.delayed_orders, 0) AS delayed_orders,
    COALESCE(cs.returned_orders, 0) AS returned_orders,
    /* ==========================================================
       ORDER RATES
       ========================================================== */
    ROUND(COALESCE(cs.returned_orders, 0)/ NULLIF(cs.total_orders, 0) * 100,2) AS return_rate_pct,
    ROUND(COALESCE(cs.cancelled_orders, 0)/ NULLIF(cs.total_orders, 0) * 100,2) AS cancellation_rate_pct,
    /* ==========================================================
       SALES CHANNEL BEHAVIOR
       ========================================================== */
    COALESCE(cs.online_orders, 0) AS online_orders,
    COALESCE(cs.instore_orders, 0) AS instore_orders,
    COALESCE(cs.mobile_orders, 0) AS mobile_orders,
    COALESCE(cs.phone_orders, 0) AS phone_orders,
    COALESCE(cs.reseller_orders, 0) AS reseller_orders,
    /* ==========================================================
       CUSTOMER RECENCY

       Based on dataset_max_date rather than CURRENT_DATE().
       This makes the analysis reproducible.
       ========================================================== */
    DATEDIFF(d.dataset_max_date,cs.last_order_date) AS recency_days,
    /* ==========================================================
       CUSTOMER LIFESPAN
       ========================================================== */
    DATEDIFF(cs.last_order_date,cs.first_order_date) AS customer_lifespan_days,
    /* ==========================================================
       CUSTOMER TENURE
       ========================================================== */
    TIMESTAMPDIFF(MONTH, c.signup_date_clean, d.dataset_max_date) AS customer_tenure_months,
    TIMESTAMPDIFF(YEAR,c.signup_date_clean,d.dataset_max_date) AS customer_tenure_years,
    /* ==========================================================
       REPEAT CUSTOMER FLAG
       ========================================================== */
    CASE
        WHEN COALESCE(cs.total_orders, 0) > 1 THEN 'Repeat Customer'
        ELSE 'One-time Customer'
    END AS repeat_customer_flag,
    /* ==========================================================
       CUSTOMER VALUE SEGMENT

       Based on realized cumulative net profit.
       ========================================================== */
    CASE
        WHEN COALESCE(cs.net_profit, 0) >= 5000 THEN 'High Value'
        WHEN COALESCE(cs.net_profit, 0) >= 2000 THEN 'Medium Value'
        ELSE 'Low Value'
    END AS customer_value_segment,
    /* ==========================================================
       CUSTOMER REVENUE TIER

       AUTHORITATIVE DEFINITION.

       This logic is deliberately located here so RFM,
       CLV and other customer views do NOT recreate it.
       ========================================================== */
    CASE
        WHEN COALESCE(cs.net_revenue, 0) = 0 THEN 'No Revenue'
        WHEN COALESCE(cs.net_revenue, 0) < 7500 THEN 'Entry'
        WHEN COALESCE(cs.net_revenue, 0) < 20000 THEN 'Standard'
        WHEN COALESCE(cs.net_revenue, 0) < 50000 THEN 'Growth'
        WHEN COALESCE(cs.net_revenue, 0) < 100000 THEN 'High Value'
        ELSE 'VIP'
    END AS customer_revenue_tier,
    /* ----------------------------------------------------------
       Revenue tier sort
       ---------------------------------------------------------- */
    CASE
        WHEN COALESCE(cs.net_revenue, 0) = 0 THEN 1
        WHEN COALESCE(cs.net_revenue, 0) < 7500 THEN 2
        WHEN COALESCE(cs.net_revenue, 0) < 20000 THEN 3
        WHEN COALESCE(cs.net_revenue, 0) < 50000 THEN 4
        WHEN COALESCE(cs.net_revenue, 0) < 100000 THEN 5
        ELSE 6
    END AS customer_revenue_tier_sort,
    /* ==========================================================
       CUSTOMER LIFECYCLE

       AUTHORITATIVE DEFINITION.

       Downstream views consume lifecycle_stage instead of
       recreating the date thresholds.
       ========================================================== */
    CASE
        WHEN DATEDIFF(d.dataset_max_date, c.signup_date_clean) <= 30 THEN 'New (0-30 days)'
        WHEN DATEDIFF(d.dataset_max_date, c.signup_date_clean) <= 90 THEN 'Recent (31-90 days)'
        WHEN DATEDIFF(d.dataset_max_date,c.signup_date_clean) <= 180 THEN 'Established (91-180 days)'
        WHEN DATEDIFF(d.dataset_max_date,c.signup_date_clean) <= 365 THEN 'Loyal (181-365 days)'
        ELSE 'Veteran (365+ days)'
    END AS customer_lifecycle_stage,
    /* ==========================================================
       PURCHASE FREQUENCY BAND

       Another reusable classification.
       ========================================================== */
    CASE
        WHEN COALESCE(cs.total_orders, 0) >= 10 THEN 'Very Frequent'
        WHEN COALESCE(cs.total_orders, 0) >= 5 THEN 'Frequent'
        WHEN COALESCE(cs.total_orders, 0) >= 2 THEN 'Occasional'
        ELSE 'One Time'
    END AS purchase_frequency_band
FROM clean_customers c
LEFT JOIN customer_sales cs
    ON c.customer_id = cs.customer_id
CROSS JOIN dataset_date d;


-- ============================================================================
-- 05. CUSTOMER LIFETIME VALUE — Fact_Customer_CLV
-- Grain: One row per customer, subject to customer_id uniqueness.
-- Purpose: Assess realized customer profitability, estimate projected lifetime
-- value, analyze acquisition economics and calculate customer health scores.
-- ============================================================================
CREATE OR REPLACE VIEW Fact_Customer_CLV AS
/* ==============================================================
   FACT CUSTOMER CLV
   ==============================================================

   Grain:
   One row per customer

   Purpose:
   - Customer profitability
   - Realized customer value
   - Projected customer lifetime value
   - Customer acquisition economics
   - CLV:CAC
   - Customer health scoring

   Reusable customer metrics are inherited from
   Fact_Customer_Base.

   This view should NOT recreate:
   - Revenue tiers
   - Lifecycle stages
   - AOV
   - Return rates
   - Cancellation rates
   - Product metrics
   - Channel metrics
   ============================================================== */

SELECT
    /* ==========================================================
       CUSTOMER IDENTIFICATION
       ========================================================== */
    cb.customer_id,
    cb.signup_date_clean,
    cb.acquisition_campaign_id,
    cb.dataset_max_date,
    /* ==========================================================
       CORE CUSTOMER METRICS
       ========================================================== */
    cb.total_orders,
    cb.first_order_date,
    cb.last_order_date,
    cb.total_units,
    cb.gross_revenue,
    cb.net_revenue,
    cb.total_cost,
    cb.net_profit,
    cb.average_order_value,
    cb.average_discount_pct,
    cb.total_discount_given,
    cb.total_shipping_cost,
    cb.average_shipping_cost,
    cb.average_delivery_days,
    cb.returned_orders,
    cb.return_rate_pct,
    cb.cancelled_orders,
    cb.cancellation_rate_pct,
    /* ==========================================================
       CUSTOMER VALUE CLASSIFICATIONS

       Inherited from Customer Base.
       ========================================================== */
    cb.customer_value_segment,
    cb.customer_revenue_tier,
    cb.customer_revenue_tier_sort,
    cb.customer_lifecycle_stage,
    cb.customer_tenure_months,
    cb.customer_tenure_years,
    cb.recency_days,
    cb.repeat_customer_flag,
    /* ==========================================================
       REALIZED CUSTOMER CLV

       In this project:
       customer_clv = cumulative historical net profit.

       This is realized value, NOT a forecast.
       ========================================================== */
    COALESCE(cb.net_profit, 0) AS customer_clv,
    /* ==========================================================
       CUSTOMER PROFIT MARGIN
       ========================================================== */
    cb.profit_margin_pct,
    /* ==========================================================
       CUSTOMER ACQUISITION COST

       Uses campaign-level spend and acquired customers.

       Important:
       CAC is NOT averaged from individual customers.

       Campaign CAC =
       Campaign Spend / Customers Acquired
       ========================================================== */
    ROUND(cp.marketing_spend/ NULLIF(cp.total_customers_acquired, 0),2) AS cac,
    /* ==========================================================
       CLV : CAC RATIO

       Realized customer profit relative to acquisition cost.
       ========================================================== */
    ROUND(COALESCE(cb.net_profit, 0)/NULLIF(cp.marketing_spend/ NULLIF(cp.total_customers_acquired, 0),0),2) AS clv_cac_ratio,
    /* ==========================================================
       PROJECTED CUSTOMER LIFETIME VALUE

       Methodology:

       AOV
       ×
       Annualized purchase frequency
       ×
       2-year modeled lifetime

       This is a simple business projection, not a statistical
       predictive model.
       ========================================================== */
    ROUND(COALESCE(cb.average_order_value, 0)* (COALESCE(cb.total_orders, 0)/
            (GREATEST(DATEDIFF(cb.dataset_max_date,cb.first_order_date),1)/ 365.0
            ))*2,2) AS projected_customer_lifetime_value,
    /* ==========================================================
       HEALTH SCORE — RECENCY COMPONENT

       Maximum contribution = 0.40
       ========================================================== */
    CASE
        WHEN cb.recency_days <= 30 THEN 0.40
        WHEN cb.recency_days <= 60 THEN 0.32
        WHEN cb.recency_days <= 90 THEN 0.24
        WHEN cb.recency_days <= 180 THEN 0.16
        ELSE 0.08
    END AS recency_health_component,
    /* ==========================================================
       HEALTH SCORE — FREQUENCY COMPONENT

       Maximum contribution = 0.30
       ========================================================== */
    CASE
        WHEN cb.total_orders >= 20 THEN 0.30
        WHEN cb.total_orders >= 10 THEN 0.24
        WHEN cb.total_orders >= 5 THEN 0.18
        WHEN cb.total_orders >= 2 THEN 0.12
        ELSE 0.06
    END AS frequency_health_component,
    /* ==========================================================
       HEALTH SCORE — REVENUE COMPONENT

       Maximum contribution = 0.30

       Revenue is intentionally used here because this is a
       customer HEALTH model, not the RFM model.
       ========================================================== */
    CASE
        WHEN cb.net_revenue >= 100000 THEN 0.30
        WHEN cb.net_revenue >= 50000 THEN 0.24
        WHEN cb.net_revenue >= 20000 THEN 0.18
        WHEN cb.net_revenue >= 7500 THEN 0.12
        WHEN cb.net_revenue > 0 THEN 0.08
        ELSE 0.04
    END AS revenue_health_component,
    /* ==========================================================
       CUSTOMER HEALTH SCORE

       Recency  = 40%
       Frequency = 30%
       Revenue = 30%

       Range:
       0.18 → 1.00 based on the current scoring rules.
       ========================================================== */
    ROUND(
        CASE
            WHEN cb.recency_days <= 30 THEN 0.40
            WHEN cb.recency_days <= 60 THEN 0.32
            WHEN cb.recency_days <= 90 THEN 0.24
            WHEN cb.recency_days <= 180 THEN 0.16
            ELSE 0.08
        END +
        CASE
            WHEN cb.total_orders >= 20 THEN 0.30
            WHEN cb.total_orders >= 10 THEN 0.24
            WHEN cb.total_orders >= 5 THEN 0.18
            WHEN cb.total_orders >= 2 THEN 0.12
            ELSE 0.06
        END
        +
        CASE
            WHEN cb.net_revenue >= 100000 THEN 0.30
            WHEN cb.net_revenue >= 50000 THEN 0.24
            WHEN cb.net_revenue >= 20000 THEN 0.18
            WHEN cb.net_revenue >= 7500 THEN 0.12
            WHEN cb.net_revenue > 0 THEN 0.08
            ELSE 0.04
        END, 2
    ) AS customer_health_score,
    /* ==========================================================
       HEALTH SCORE COMPONENTS — 10 TO 50 SCALE

       These are retained specifically for Power BI explainability.
       ========================================================== */
    CASE
        WHEN cb.recency_days <= 30 THEN 50
        WHEN cb.recency_days <= 60 THEN 40
        WHEN cb.recency_days <= 90 THEN 30
        WHEN cb.recency_days <= 180 THEN 20
        ELSE 10
    END AS recency_score,
    CASE
        WHEN cb.total_orders >= 20 THEN 50
        WHEN cb.total_orders >= 10 THEN 40
        WHEN cb.total_orders >= 5 THEN 30
        WHEN cb.total_orders >= 2 THEN 20
        ELSE 10
    END AS frequency_score,
    CASE
        WHEN cb.net_revenue >= 100000 THEN 50
        WHEN cb.net_revenue >= 50000 THEN 40
        WHEN cb.net_revenue >= 20000 THEN 30
        WHEN cb.net_revenue >= 7500 THEN 20
        WHEN cb.net_revenue > 0 THEN 10
        ELSE 5
    END AS revenue_score
FROM Fact_Customer_Base cb
LEFT JOIN Fact_Campaign_Performance cp
    ON cb.acquisition_campaign_id = cp.campaign_id;
-- ============================================================================
-- 06. RFM CUSTOMER SEGMENTATION — Fact_RFM_Segmentation
-- Grain: One row per customer.
-- Purpose: Classify customers using recency, frequency and monetary value to
-- support retention planning, customer prioritization and differentiated
-- customer treatment.
-- ============================================================================

CREATE OR REPLACE VIEW Fact_RFM_Segmentation AS
/* ==============================================================
   FACT RFM SEGMENTATION
   ==============================================================
   Grain:
   One row per customer

   Purpose:
   - Relative customer behavioral segmentation
   - Retention targeting
   - Customer prioritization
   - RFM analysis
   - Commercial customer strategy

   RFM:
   R = Recency
   F = Frequency
   M = Monetary

   Monetary is defined in this project as cumulative NET PROFIT.

   This is deliberately different from:
   customer_revenue_tier
   which is based on NET REVENUE.

   Reusable customer metrics come from Fact_Customer_Base.
   ============================================================== */

WITH rfm_scored AS
(
    SELECT
        cb.*,
        /* ======================================================
           RFM QUINTILE SCORING

           Recency:
           Lower recency_days = better.

           DESC therefore gives the most recent customers
           the highest score.
           ====================================================== */
        NTILE(5) OVER (ORDER BY cb.recency_days DESC) AS recency_rfm_score,
        /* ======================================================
           FREQUENCY

           Higher number of orders = better.
           ====================================================== */
        NTILE(5) OVER (ORDER BY cb.total_orders ASC) AS frequency_rfm_score,
        /* ======================================================
           MONETARY

           Higher cumulative net profit = better.
           ====================================================== */
        NTILE(5) OVER (ORDER BY cb.net_profit ASC) AS monetary_rfm_score
    FROM Fact_Customer_Base cb
),
classified AS
(
    SELECT
        r.*,
        /* ======================================================
           RFM COMPOSITE SCORE
           ====================================================== */
        CONCAT(r.recency_rfm_score, r.frequency_rfm_score, r.monetary_rfm_score) AS rfm_score,
        /* ======================================================
           RFM CUSTOMER SEGMENT
           ====================================================== */
        CASE
            WHEN r.recency_rfm_score >= 4 AND r.frequency_rfm_score >= 4  AND r.monetary_rfm_score >= 4 THEN 'Champions'
            WHEN r.recency_rfm_score >= 3 AND r.frequency_rfm_score >= 4 AND r.monetary_rfm_score >= 3 THEN 'Loyal Customers'
            WHEN r.recency_rfm_score >= 4 AND r.frequency_rfm_score >= 2 THEN 'Potential Loyalists'
            WHEN r.recency_rfm_score = 5 AND r.frequency_rfm_score = 1 THEN 'New Customers'
            WHEN r.recency_rfm_score >= 3 AND r.frequency_rfm_score >= 2 THEN 'Promising'
            WHEN r.recency_rfm_score = 2 AND r.frequency_rfm_score >= 3 THEN 'Need Attention'
            WHEN r.recency_rfm_score <= 2 AND r.frequency_rfm_score = 5 AND r.monetary_rfm_score >= 4 THEN 'Cant Lose Them'
            WHEN r.recency_rfm_score <= 2 AND r.frequency_rfm_score >= 3 AND r.monetary_rfm_score >= 3 THEN 'At Risk'
            WHEN r.recency_rfm_score <= 2 AND r.frequency_rfm_score <= 2 THEN 'Hibernating'
            ELSE 'Lost Customers'
        END AS rfm_segment
    FROM rfm_scored r
)
SELECT
    /* ==========================================================
       CUSTOMER IDENTIFICATION
       ========================================================== */
    customer_id,
    dataset_max_date,
    first_order_date,
    last_order_date,
    /* ==========================================================
       RFM CORE METRICS
       ========================================================== */
    recency_days,
    total_orders AS frequency,
    net_profit AS monetary,
    recency_rfm_score,
    frequency_rfm_score,
    monetary_rfm_score,
    rfm_score,
    rfm_segment,
    /* ==========================================================
       CUSTOMER ACTIVITY
       ========================================================== */
    CASE
        WHEN recency_days <= 30 THEN 'Active'
        WHEN recency_days <= 90 THEN 'Warm'
        WHEN recency_days <= 180 THEN 'Cooling'
        ELSE 'Inactive'
    END AS activity_status,
    /* ==========================================================
       CUSTOMER LIFESPAN
       ========================================================== */
    customer_lifespan_days,
    /* ==========================================================
       FINANCIAL METRICS

       Inherited from customer base.
       ========================================================== */
    gross_revenue,
    net_revenue,
    net_profit,
    total_cost,
    total_discount_given,
    total_shipping_cost,
    average_order_value,
    profit_margin_pct,
    /* ==========================================================
       CUSTOMER VALUE CLASSIFICATIONS

       IMPORTANT:
       We do NOT recreate revenue-tier CASE logic here.

       These are inherited from Fact_Customer_Base.
       ========================================================== */
    customer_revenue_tier,
    customer_revenue_tier_sort,
    customer_value_segment,
    customer_lifecycle_stage,
    purchase_frequency_band,
    /* ==========================================================
       PRODUCT / PURCHASE BEHAVIOR
       ========================================================== */
    unique_products_purchased,
    total_units,
    /* ==========================================================
       ORDER / OPERATIONAL BEHAVIOR
       ========================================================== */
    cancelled_orders,
    delayed_orders,
    returned_orders,
    return_rate_pct,
    cancellation_rate_pct,
    /* ==========================================================
       CHANNEL PREFERENCE
       ========================================================== */
    online_orders,
    instore_orders,
    mobile_orders,
    phone_orders,
    reseller_orders,
    /* ==========================================================
       ORDER ECONOMICS
       ========================================================== */
    ROUND(net_profit / NULLIF(frequency, 0),2) AS avg_profit_per_order,
    /* ==========================================================
       RFM PROFIT MARGIN

       Same underlying base metric, simply exposed under
       RFM analysis.
       ========================================================== */
    profit_margin_pct AS customer_profit_margin_pct,
    /* ==========================================================
       PRICING POLICY

       This is a BUSINESS STRATEGY layer.

       Notice that we use NET REVENUE for revenue thresholds
       and NET PROFIT for profitability requirements.

       We do not incorrectly use RFM "monetary" (profit) as
       revenue.
       ========================================================== */
    CASE
        WHEN net_revenue >= 99000 AND net_profit >= 30000 AND recency_rfm_score >= 4 THEN 'VIP Strategic'
        WHEN net_revenue >= 49000 AND net_profit >= 15000 AND recency_rfm_score >= 3 THEN 'Preferred'
        WHEN net_revenue >= 22000 AND net_profit >= 7500 THEN 'Premium'
        WHEN net_revenue >= 8000 THEN 'Growth'
        WHEN net_revenue > 0 THEN 'Standard'
        ELSE 'Entry'
    END AS pricing_policy,
    /* ==========================================================
       RECOMMENDED MAXIMUM DISCOUNT

       Business decision rule based on:
       - Customer revenue
       - Customer profit
       - Customer recency
       ========================================================== */
    CASE
        WHEN net_revenue >= 99000 AND net_profit >= 30000 AND recency_rfm_score >= 4 THEN 15
        WHEN net_revenue >= 49000 AND net_profit >= 15000 AND recency_rfm_score >= 3 THEN 12
        WHEN net_revenue >= 22000 AND net_profit >= 7500 THEN 10
        WHEN net_revenue >= 8000 THEN 8 WHEN net_revenue > 0 THEN 5
        ELSE 3
    END AS recommended_max_discount_pct
FROM classified;


-- ============================================================================
-- 07. MARKETING ATTRIBUTION MART — mart_marketing_attribution
-- Grain: One row per campaign, subject to campaign_id uniqueness.
-- Purpose: Compare platform-attributed revenue with internal sales outcomes,
-- assess marketing profitability, analyze customer value relative to
-- acquisition cost and estimate campaign payback periods.
-- ============================================================================
DROP TABLE IF EXISTS mart_m2_marketing_attribution;
SELECT * FROM  mart_marketing_attribution;
CREATE OR REPLACE VIEW mart_marketing_attribution AS
/* ==============================================================
   MART M2 — MARKETING ATTRIBUTION
   ==============================================================
   Grain:
   One row per campaign

   Purpose:
   - Campaign performance
   - Platform vs internal revenue comparison
   - Marketing profitability
   - Customer value generated by acquisition
   - CLV:CAC analysis
   - Campaign payback estimation

   Sources:
   Fact_Campaign_Performance
   Fact_Customer_CLV

   This mart intentionally does NOT recalculate customer-level
   sales metrics from clean_sales.
   ============================================================== */
WITH campaign_clv AS
(
    /* ==========================================================
       CUSTOMER VALUE BY ACQUISITION CAMPAIGN

       Customer CLV is already calculated at customer level.

       We aggregate it to campaign level using the average
       customer CLV among customers acquired by each campaign.
       ========================================================== */
    SELECT
        acquisition_campaign_id AS campaign_id,
        COUNT(DISTINCT customer_id) AS acquired_customers_with_clv,
        ROUND(AVG(customer_clv), 2) AS average_customer_clv,
        ROUND(AVG(projected_customer_lifetime_value),2) AS average_projected_customer_lifetime_value
    FROM Fact_Customer_CLV
    WHERE acquisition_campaign_id IS NOT NULL
    GROUP BY acquisition_campaign_id
)
SELECT
    /* ==========================================================
       CAMPAIGN IDENTIFICATION
       ========================================================== */
    cp.campaign_id,
    cp.start_date_clean,
    cp.duration_days,
    cp.campaign_year,
    cp.campaign_quarter,
    cp.campaign_month,
    /* ==========================================================
       CAMPAIGN INFORMATION
       ========================================================== */
    cp.campaign_budget,
    cp.marketing_spend,
    cp.total_customers_acquired,
    /* ==========================================================
       MARKETING FUNNEL
       ========================================================== */
    cp.impressions,
    cp.clicks,
    cp.conversions,
    cp.actual_cpc,
    cp.actual_cpa,
    cp.cpm,
    cp.ctr_pct,
    cp.conversion_rate_pct,
    /* ==========================================================
       PLATFORM ATTRIBUTION
       ========================================================== */
    cp.attributed_revenue,
    cp.roas AS platform_roas,
    /* ==========================================================
       INTERNAL SALES ATTRIBUTION
       ========================================================== */
    cp.total_orders,
    cp.products_sold,
    cp.units_sold,
    cp.total_sales_revenue,
    cp.total_sales_cost,
    cp.net_profit,
    cp.average_order_value,
    cp.average_discount_pct,
    cp.average_shipping_cost,
    cp.return_rate_pct,
    cp.delivery_rate_pct,
    cp.average_delivery_days,
    /* ==========================================================
       ATTRIBUTION GAP

       Positive:
       Platform reports more revenue than internal sales.

       Negative:
       Internal sales exceed platform-attributed revenue.
       ========================================================== */
    ROUND(cp.attributed_revenue - cp.total_sales_revenue, 2) AS platform_attribution_gap,
    ROUND((cp.attributed_revenue - cp.total_sales_revenue)/NULLIF(cp.total_sales_revenue, 0)* 100,2) AS platform_attribution_gap_pct,
    /* ==========================================================
       ACTUAL ROAS

       Uses internally recorded sales revenue rather than
       platform-attributed revenue.
       ========================================================== */
    ROUND(cp.total_sales_revenue/ NULLIF(cp.marketing_spend, 0),2) AS actual_roas,
    /* ==========================================================
       MARKETING PROFIT

       Internal net profit less campaign marketing spend.
       ========================================================== */
    ROUND(cp.net_profit - cp.marketing_spend, 2) AS marketing_profit,
    /* ==========================================================
       MARKETING ROI
       ========================================================== */
    ROUND((cp.net_profit - cp.marketing_spend) /NULLIF(cp.marketing_spend, 0)* 100,2) AS marketing_roi_pct,
    /* ==========================================================
       CUSTOMER ACQUISITION COST

       Campaign-level CAC.
       ========================================================== */
    ROUND(cp.marketing_spend / NULLIF(cp.total_customers_acquired, 0), 2) AS cac,
    /* ==========================================================
       CUSTOMER VALUE

       Average realized CLV of customers acquired through
       the campaign.
       ========================================================== */
    COALESCE(cclv.average_customer_clv, 0) AS average_customer_clv,
    COALESCE(cclv.average_projected_customer_lifetime_value,0) AS average_projected_customer_lifetime_value,
    /* ==========================================================
       CLV : CAC

       Indicates how much realized customer profit was generated
       for every unit of acquisition cost.
       ========================================================== */
    ROUND(COALESCE(cclv.average_customer_clv, 0)/NULLIF(cp.marketing_spend/NULLIF(cp.total_customers_acquired, 0),0),2) AS clv_cac_ratio,
    /* ==========================================================
       PROFIT TO AD SPEND RATIO
       ========================================================== */
    ROUND(cp.net_profit/NULLIF(cp.marketing_spend, 0),2) AS profit_to_ad_spend_ratio,
    /* ==========================================================
       ESTIMATED PAYBACK PERIOD

       IMPORTANT:
       This is an ESTIMATE.

       Assumption:
       campaign profit is generated evenly across the
       campaign duration.

       We therefore keep it here at campaign level where
       duration_days actually exists.

       We do NOT arbitrarily assume 365 days at channel level.
       ========================================================== */
    ROUND(cp.marketing_spend/ NULLIF(cp.net_profit/NULLIF(cp.duration_days, 0),0),2) AS estimated_payback_period_days,
    /* ==========================================================
       CAMPAIGN PERFORMANCE CLASSIFICATION
       ========================================================== */
    cp.performance_rating,
    /* ==========================================================
       CUSTOMER VALUE QUALITY

       Additional interpretation of acquisition quality.
       ========================================================== */
    CASE
        WHEN COALESCE(cclv.average_customer_clv, 0) /NULLIF(cp.marketing_spend/NULLIF(cp.total_customers_acquired, 0),0) >= 5 
        THEN 'Excellent Customer Economics'
        WHEN COALESCE(cclv.average_customer_clv, 0)/NULLIF(cp.marketing_spend/NULLIF(cp.total_customers_acquired, 0),0) >= 3
		THEN 'Strong Customer Economics'
        WHEN COALESCE(cclv.average_customer_clv, 0)/
             NULLIF(cp.marketing_spend / NULLIF(cp.total_customers_acquired, 0),0) >= 2
            THEN 'Acceptable Customer Economics'
        WHEN COALESCE(cclv.average_customer_clv, 0)/NULLIF(cp.marketing_spend/ NULLIF(cp.total_customers_acquired, 0),0) >= 1
            THEN 'Low Customer Economics'
        ELSE 'Poor Customer Economics'
    END AS customer_economics_rating
FROM Fact_Campaign_Performance cp
LEFT JOIN campaign_clv cclv
    ON cp.campaign_id = cclv.campaign_id;

-- ============================================================================
-- 08. FACT VIEW VALIDATION & RECONCILIATION
-- Purpose:
--   - Verify row counts and declared grain.
--   - Check business-key uniqueness and missing values.
--   - Reconcile financial and operational metrics against source data.
--   - Check for duplicated measures caused by joins or mismatched grains.
--   - Confirm that downstream views produce reliable results for Power BI.
-- ============================================================================
SELECT 'fact_sales' AS view_name, COUNT(*) AS row_count
FROM fact_sales
UNION ALL
SELECT 'fact_supply_chain', COUNT(*)
FROM fact_supply_chain
UNION ALL
SELECT 'fact_campaign_performance', COUNT(*)
FROM fact_campaign_performance
UNION ALL
SELECT 'Fact_Customer_Base', COUNT(*)
FROM Fact_Customer_Base
UNION ALL
SELECT 'Fact_Customer_CLV', COUNT(*)
FROM Fact_Customer_CLV
UNION ALL
SELECT 'Fact_RFM_Segmentation', COUNT(*)
FROM Fact_RFM_Segmentation
UNION ALL
SELECT 'mart_marketing_attribution', COUNT(*)
FROM mart_marketing_attribution;


-- ============================================================================
-- 08.2 CUSTOMER-LEVEL GRAIN VALIDATION
-- Purpose: Check whether each customer appears once in customer-level views.
-- Expected: The query returns zero rows for each view.
-- ============================================================================

SELECT
    'Fact_Customer_Base' AS view_name,
    customer_id,
    COUNT(*) AS duplicate_count
FROM Fact_Customer_Base
GROUP BY customer_id
HAVING customer_id IS NULL OR COUNT(*) > 1;


SELECT
    'Fact_Customer_CLV' AS view_name,
    customer_id,
    COUNT(*) AS duplicate_count
FROM Fact_Customer_CLV
GROUP BY customer_id
HAVING customer_id IS NULL OR COUNT(*) > 1;


SELECT
    'Fact_RFM_Segmentation' AS view_name,
    customer_id,
    COUNT(*) AS duplicate_count
FROM Fact_RFM_Segmentation
GROUP BY customer_id
HAVING customer_id IS NULL OR COUNT(*) > 1;


-- ============================================================================
-- 08.3 CAMPAIGN-LEVEL GRAIN VALIDATION
-- Purpose: Check campaign uniqueness in campaign-level views.
-- Expected: Zero rows if each view contains one record per campaign.
-- ============================================================================

SELECT
    'fact_campaign_performance' AS view_name,
    campaign_id,
    COUNT(*) AS duplicate_count
FROM fact_campaign_performance
GROUP BY campaign_id
HAVING campaign_id IS NULL OR COUNT(*) > 1;


SELECT
    'mart_marketing_attribution' AS view_name,
    campaign_id,
    COUNT(*) AS duplicate_count
FROM mart_marketing_attribution
GROUP BY campaign_id
HAVING campaign_id IS NULL OR COUNT(*) > 1;


-- ============================================================================
-- 08.4 SALES BUSINESS-KEY COMPLETENESS
-- Purpose: Identify sales records missing important identifiers.
-- Note: order_id can repeat when an order contains multiple product lines.
-- Expected: Investigate any rows returned.
-- ============================================================================

SELECT
    COUNT(*) AS total_sales_rows,
    SUM(order_id IS NULL) AS missing_order_id,
    SUM(customer_id IS NULL) AS missing_customer_id,
    SUM(product_id IS NULL) AS missing_product_id,
    SUM(order_date_clean IS NULL) AS missing_order_date
FROM fact_sales;


-- ============================================================================
-- 08.5 SALES ROW-COUNT RECONCILIATION
-- Purpose: Compare the analytical sales view with its cleaned source.
-- Expected: Matching row counts if fact_sales is a direct row-preserving
-- projection of clean_sales.
-- ============================================================================

SELECT
    'clean_sales' AS source_name,
    COUNT(*) AS row_count
FROM clean_sales
UNION ALL
SELECT
    'fact_sales' AS source_name,
    COUNT(*) AS row_count
FROM fact_sales;


-- ============================================================================
-- 08.6 SALES FINANCIAL RECONCILIATION
-- Purpose: Compare revenue, costs and profit between the cleaned source and
-- the analytical sales view.
-- Expected: Differences of zero if the view preserves these measures.
-- ============================================================================

SELECT
    'gross_revenue' AS metric,
    ROUND((SELECT COALESCE(SUM(gross_revenue), 0)
         FROM clean_sales)
        -
        (SELECT COALESCE(SUM(gross_revenue), 0) FROM fact_sales),2) AS difference
UNION ALL
SELECT
    'net_revenue',
    ROUND(
        (SELECT COALESCE(SUM(net_revenue), 0) FROM clean_sales)
        -
        (SELECT COALESCE(SUM(net_revenue), 0)
         FROM fact_sales),2)
UNION ALL
SELECT
    'cogs',
    ROUND(
        (SELECT COALESCE(SUM(cogs), 0)
         FROM clean_sales)
        -
        (SELECT COALESCE(SUM(cogs), 0)
         FROM fact_sales),
        2
    )
UNION ALL
SELECT
    'net_profit',
    ROUND(
        (SELECT COALESCE(SUM(net_profit), 0)
         FROM clean_sales)
        -
        (SELECT COALESCE(SUM(net_profit), 0)
         FROM fact_sales),
        2
    );


-- ============================================================================
-- 08.7 SALES FINANCIAL LOGIC CHECKS
-- Purpose: Find missing financial values and records that may require review.
-- Note: Negative values are not automatically errors; returns and adjustments
-- can legitimately produce them.
-- Expected: Review any records returned by the second query.
-- ============================================================================

SELECT
    COUNT(*) AS total_rows,
    SUM(gross_revenue IS NULL) AS missing_gross_revenue,
    SUM(net_revenue IS NULL) AS missing_net_revenue,
    SUM(cogs IS NULL) AS missing_cogs,
    SUM(net_profit IS NULL) AS missing_net_profit
FROM fact_sales;


SELECT
    order_id,
    customer_id,
    product_id,
    gross_revenue,
    net_revenue,
    cogs,
    net_profit
FROM fact_sales
WHERE gross_revenue IS NOT NULL
  AND net_revenue IS NOT NULL
  AND cogs IS NOT NULL
  AND net_profit IS NOT NULL
  AND ABS(net_profit - (net_revenue - cogs)) > 0.02
LIMIT 100;


-- ============================================================================
-- 08.8 SUPPLY CHAIN ROW-COUNT RECONCILIATION
-- Purpose: Compare the supply chain view with its cleaned source.
-- Expected: Matching counts if fact_supply_chain is a direct projection.
-- ============================================================================

SELECT
    'clean_supply_chain' AS source_name,
    COUNT(*) AS row_count
FROM clean_supply_chain
UNION ALL
SELECT
    'fact_supply_chain' AS source_name,
    COUNT(*) AS row_count
FROM fact_supply_chain;


-- ============================================================================
-- 08.9 SUPPLY CHAIN KEY COMPLETENESS
-- Purpose: Identify missing purchase-order and product identifiers.
-- Note: Do not assume po_id is unique until you confirm the source grain.
-- Expected: Zero missing identifiers, unless documented exceptions exist.
-- ============================================================================

SELECT
    COUNT(*) AS total_rows,
    SUM(po_id IS NULL) AS missing_po_id,
    SUM(product_id IS NULL) AS missing_product_id,
    SUM(supplier_code IS NULL) AS missing_supplier_code,
    SUM(warehouse_id IS NULL) AS missing_warehouse_id
FROM fact_supply_chain;


-- ============================================================================
-- 08.10 CAMPAIGN SOURCE RECONCILIATION
-- Purpose: Compare campaign performance with cleaned marketing data.
-- Expected: Matching row counts and financial totals for a direct projection.
-- ============================================================================

SELECT
    'clean_marketing_campaigns' AS source_name,
    COUNT(*) AS row_count
FROM clean_marketing_campaigns

UNION ALL

SELECT
    'fact_campaign_performance' AS source_name,
    COUNT(*) AS row_count
FROM fact_campaign_performance;


SELECT
    'budget' AS metric,
    ROUND(
        (SELECT COALESCE(SUM(budget), 0)
         FROM clean_marketing_campaigns)
        -
        (SELECT COALESCE(SUM(budget), 0)
         FROM fact_campaign_performance),
        2
    ) AS difference

UNION ALL

SELECT
    'amount_spent',
    ROUND(
        (SELECT COALESCE(SUM(amount_spent), 0)
         FROM clean_marketing_campaigns)
        -
        (SELECT COALESCE(SUM(amount_spent), 0)
         FROM fact_campaign_performance),
        2
    )

UNION ALL

SELECT
    'attributed_revenue',
    ROUND(
        (SELECT COALESCE(SUM(attributed_revenue), 0)
         FROM clean_marketing_campaigns)
        -
        (SELECT COALESCE(SUM(attributed_revenue), 0)
         FROM fact_campaign_performance),
        2
    );


-- ============================================================================
-- 08.11 DATE AND MEASURE COMPLETENESS
-- Purpose: Review the completeness of important dates and financial measures.
-- Expected: Use the results to identify fields requiring further investigation.
-- ============================================================================

SELECT
    'fact_sales' AS view_name,
    COUNT(*) AS total_rows,
    SUM(order_date_clean IS NULL) AS missing_primary_date
FROM fact_sales

UNION ALL

SELECT
    'fact_supply_chain',
    COUNT(*),
    SUM(order_date_clean IS NULL)
FROM fact_supply_chain;


-- ============================================================================
-- END OF FACT VIEW VALIDATION & RECONCILIATION
-- ============================================================================















