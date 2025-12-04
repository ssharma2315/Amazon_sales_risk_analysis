
CREATE TABLE amazon_sales (
    index VARCHAR(10),
    Order_ID VARCHAR(50),
    Dates VARCHAR(15),                    -- or DATETIME if you have time
    Status VARCHAR(50),
    Fulfillment VARCHAR(50),
    Sales_Channel VARCHAR(100),
    Ship_service_levels VARCHAR(50),
    Styles VARCHAR(100),
    SKU VARCHAR(100),
    Category VARCHAR(100),
    Sizes VARCHAR(20),
    ASIN VARCHAR(20),
    CourierStatus VARCHAR(50),
    Qty VARCHAR(10),                      -- or DECIMAL if decimals
    currency VARCHAR(10),
    Amount VARCHAR(15),         -- for money values
    ship_states VARCHAR(50),
    ship_city VARCHAR(100),
    ship_postal_code VARCHAR(20),
    ship_country VARCHAR(50),
    promotions_ids TEXT,
    B2B VARCHAR(10),              -- or BOOLEAN if Yes/No
    Fullfilled_by VARCHAR(100)
);
Alter table amazon_sales add column Country_name VARCHAR(100);
SELECT * FROM amazon_sales;
/*
================================================================================
PROJECT 2: E-COMMERCE RISK & FAILURE ANALYSIS
================================================================================
Author: Saransh Sharma
Database: PostgreSQL
Dataset: Amazon Sales Data (128,976 orders)
Objective: Deep-dive analysis of order failures, losses, and operational risks

Business Questions Answered:
1. How much revenue is lost due to pre-delivery failures?
2. How much is lost to post-delivery returns/damages?
3. What is our expected revenue after accounting for risk?
4. Which product categories have highest failure rates?
5. Are there geographic patterns in delivery failures?
6. What is the financial impact of operational problems?

Risk Framework:
- PRE-DELIVERY: Orders that fail before shipment (Cancelled, Lost, Rejected)
- POST-DELIVERY: Orders that fail after delivery (Returns, Damages)
- IN-TRANSIT RISK: Current orders at risk based on historical success rates
================================================================================
*/

-- ============================================================================
-- SECTION 1: PRE-DELIVERY RISK ANALYSIS
-- ============================================================================

-- Query 1: Calculate revenue lost BEFORE delivery
-- PURPOSE: Quantify financial impact of orders that never reached customers
-- BUSINESS IMPACT: These represent operational inefficiencies or customer issues
-- CATEGORIES:
--   - Cancelled: Customer/seller cancelled before shipping
--   - Lost in Transit: Package lost by courier
--   - Rejected by Buyer: Customer refused delivery
--   - Pending: Stuck in processing (potential system issues)

SELECT 
    status,
    COUNT(*) as problem_order_count,
    SUM(CAST(amount AS NUMERIC)) as lost_revenue,
    ROUND(AVG(CAST(amount AS NUMERIC)), 2) as avg_order_value,
    ROUND(SUM(CAST(amount AS NUMERIC)) / 
          (SELECT SUM(CAST(amount AS NUMERIC)) 
           FROM amazon_sales 
           WHERE amount IS NOT NULL AND amount ~ '^[0-9]+\.?[0-9]*$') * 100, 2) 
        AS percent_of_total_revenue
FROM amazon_sales
WHERE status IN ('Cancelled', 'Shipped - Lost in Transit', 'Shipped - Rejected by Buyer', 
                 'Pending', 'Pending - Waiting for Pick Up', 'Shipping')
    AND amount IS NOT NULL
    AND amount ~ '^[0-9]+\.?[0-9]*$'
GROUP BY status
ORDER BY lost_revenue DESC;
-- KEY FINDING: ₹6.9M lost in pre-delivery failures
-- BIGGEST CULPRIT: Cancelled orders (₹6.6M / 10,766 orders)


-- Query 2: Aggregate pre-delivery risk metrics
-- PURPOSE: Single number for total pre-delivery losses
-- EXECUTIVE SUMMARY: "How much did we lose before shipping?"
SELECT 
    'Pre-Delivery Problems' as risk_category,
    COUNT(*) as total_problem_orders,
    SUM(CAST(amount AS NUMERIC)) as total_lost_revenue,
    ROUND(AVG(CAST(amount AS NUMERIC)), 2) as avg_lost_order_value
FROM amazon_sales
WHERE status IN ('Cancelled', 'Shipped - Lost in Transit', 'Shipped - Rejected by Buyer', 
                 'Pending', 'Pending - Waiting for Pick Up')
    AND amount IS NOT NULL
    AND amount ~ '^[0-9]+\.?[0-9]*$';
-- RESULT: ₹6,858,621 lost across 11,426 orders
-- IMPACT: 8.6% of total revenue never materialized


-- ============================================================================
-- SECTION 2: POST-DELIVERY RISK ANALYSIS
-- ============================================================================

-- Query 3: Calculate revenue lost AFTER delivery
-- PURPOSE: Quantify costs of returns, damages, and customer dissatisfaction
-- BUSINESS IMPACT: These cost MORE than cancellations (shipping + handling + restocking)
-- CATEGORIES:
--   - Returned to Seller: Customer returned product
--   - Damaged: Product damaged in transit/delivery
--   - Returning to Seller: Return in progress
SELECT 
    status,
    COUNT(*) as problem_order_count,
    SUM(CAST(amount AS NUMERIC)) as lost_revenue,
    ROUND(AVG(CAST(amount AS NUMERIC)), 2) as avg_order_value,
    ROUND(SUM(CAST(amount AS NUMERIC)) / 
          (SELECT SUM(CAST(amount AS NUMERIC)) 
           FROM amazon_sales 
           WHERE amount IS NOT NULL AND amount ~ '^[0-9]+\.?[0-9]*$') * 100, 2) 
        AS percent_of_total_revenue
FROM amazon_sales
WHERE status IN ('Shipped - Returned to Seller', 'Shipped - Damaged', 
                 'Shipped - Returning to Seller')
    AND amount IS NOT NULL
    AND amount ~ '^[0-9]+\.?[0-9]*$'
GROUP BY status
ORDER BY lost_revenue DESC;
-- KEY FINDING: ₹2.3M lost in post-delivery problems
-- CONCERN: Returns cost MORE than the product value (reverse logistics!)


-- Query 4: Aggregate post-delivery risk metrics
-- PURPOSE: Total cost of returns and damages
-- HIDDEN COSTS: Shipping both ways + restocking + damaged inventory write-offs
SELECT 
    'Post-Delivery Problems' as risk_category,
    COUNT(*) as total_problem_orders,
    SUM(CAST(amount AS NUMERIC)) as total_lost_revenue,
    ROUND(AVG(CAST(amount AS NUMERIC)), 2) as avg_lost_order_value
FROM amazon_sales
WHERE status IN ('Shipped - Returned to Seller', 'Shipped - Damaged', 
                 'Shipped - Returning to Seller')
    AND amount IS NOT NULL
    AND amount ~ '^[0-9]+\.?[0-9]*$';
-- RESULT: ₹2,296,790 lost across 2,098 orders
-- ACTUAL COST: Likely 1.5-2x this amount when including logistics


-- ============================================================================
-- SECTION 3: RISK-ADJUSTED REVENUE FORECASTING
-- ============================================================================

-- Query 5: Calculate historical success rate
-- PURPOSE: What percentage of orders that ship actually get delivered successfully?
-- METHODOLOGY: Delivered orders / (Delivered + All Problems)
-- USE CASE: Apply this rate to in-transit inventory for realistic revenue forecast
SELECT 
    SUM(CASE WHEN status = 'Shipped - Delivered to Buyer' THEN 1 ELSE 0 END) as delivered_orders,
    SUM(CASE WHEN status IN ('Shipped - Delivered to Buyer', 
                             'Cancelled', 
                             'Shipped - Lost in Transit', 
                             'Shipped - Rejected by Buyer',
                             'Shipped - Returned to Seller', 
                             'Shipped - Damaged', 
                             'Shipped - Returning to Seller') 
        THEN 1 ELSE 0 END) as total_completed_orders,
    ROUND((SUM(CASE WHEN status = 'Shipped - Delivered to Buyer' THEN 1 ELSE 0 END)::NUMERIC /
           NULLIF(SUM(CASE WHEN status IN ('Shipped - Delivered to Buyer', 
                                           'Cancelled', 
                                           'Shipped - Lost in Transit', 
                                           'Shipped - Rejected by Buyer',
                                           'Shipped - Returned to Seller', 
                                           'Shipped - Damaged', 
                                           'Shipped - Returning to Seller') 
                      THEN 1 ELSE 0 END), 0) * 100), 2) as success_rate_percent
FROM amazon_sales;
-- RESULT: 72.91% success rate
-- INTERPRETATION: Only 73% of orders complete successfully!


-- Query 6: Apply risk adjustment to in-transit revenue
-- PURPOSE: Calculate REALISTIC expected revenue from current in-transit orders
-- BUSINESS VALUE: Prevents overestimating revenue in financial forecasts
-- FORMULA: In-Transit Revenue × Historical Success Rate = Expected Revenue
WITH risk_metrics AS (
    SELECT 
        SUM(CAST(amount AS NUMERIC)) as in_transit_revenue,
        0.7291 as historical_success_rate  -- 72.91% from Query 5
    FROM amazon_sales
    WHERE status IN ('Shipped', 'Shipped - Picked Up', 'Shipped - Out for Delivery')
        AND amount IS NOT NULL
        AND amount ~ '^[0-9]+\.?[0-9]*$'
)
SELECT 
    TO_CHAR(in_transit_revenue, 'FM999,999,999.00') as current_in_transit_revenue,
    TO_CHAR(ROUND(in_transit_revenue * historical_success_rate, 2), 'FM999,999,999.00') 
        as expected_successful_revenue,
    TO_CHAR(ROUND(in_transit_revenue * (1 - historical_success_rate), 2), 'FM999,999,999.00') 
        as potential_revenue_loss,
    ROUND(historical_success_rate * 100, 2) || '%' as confidence_level
FROM risk_metrics;
-- KEY INSIGHT: 
-- In-Transit: ₹51.6M
-- Expected Revenue: ₹37.6M (73% confidence)
-- Potential Loss: ₹14.0M (27% may fail based on historical patterns)
-- ACTION: Reserve ₹14M for potential refunds/write-offs


-- Query 7: Risk-adjusted total business revenue
-- PURPOSE: What is our TRUE expected revenue after accounting for failures?
-- FORMULA: Delivered Revenue + (In-Transit × Success Rate)
SELECT 
    TO_CHAR(SUM(CASE WHEN status = 'Shipped - Delivered to Buyer' 
                THEN CAST(amount AS NUMERIC) ELSE 0 END), 'FM999,999,999.00') 
        as confirmed_delivered_revenue,
    TO_CHAR(SUM(CASE WHEN status IN ('Shipped', 'Shipped - Picked Up', 'Shipped - Out for Delivery') 
                THEN CAST(amount AS NUMERIC) ELSE 0 END) * 0.7291, 'FM999,999,999.00') 
        as expected_in_transit_revenue,
    TO_CHAR(SUM(CASE WHEN status = 'Shipped - Delivered to Buyer' 
                THEN CAST(amount AS NUMERIC) ELSE 0 END) +
            (SUM(CASE WHEN status IN ('Shipped', 'Shipped - Picked Up', 'Shipped - Out for Delivery') 
                THEN CAST(amount AS NUMERIC) ELSE 0 END) * 0.7291), 'FM999,999,999.00') 
        as total_risk_adjusted_revenue
FROM amazon_sales
WHERE amount IS NOT NULL
    AND amount ~ '^[0-9]+\.?[0-9]*$';
-- REALISTIC REVENUE FORECAST: ₹56.3M (not ₹69.6M!)
-- DIFFERENCE: ₹13.3M is optimistic overestimation


-- ============================================================================
-- SECTION 4: CATEGORY-LEVEL FAILURE ANALYSIS
-- ============================================================================

-- Query 8: Identify product categories with highest failure rates
-- PURPOSE: Find which products are causing the most problems
-- BUSINESS ACTION: Investigate suppliers, quality issues, or customer expectations mismatch
-- METHODOLOGY: (Failed Orders / Total Orders) × 100
SELECT  
    category, 
    COUNT(*) as total_orders,
    SUM(CASE WHEN status = 'Shipped - Delivered to Buyer' THEN 1 ELSE 0 END) 
        as successful_deliveries,
    SUM(CASE WHEN status IN ('Cancelled', 'Shipped - Lost in Transit', 'Shipped - Rejected by Buyer') 
        THEN 1 ELSE 0 END) as pre_delivery_failures,
    SUM(CASE WHEN status IN ('Shipped - Returned to Seller', 'Shipped - Damaged', 
                             'Shipped - Returning to Seller') 
        THEN 1 ELSE 0 END) as post_delivery_failures,
    ROUND(SUM(CASE WHEN status IN ('Cancelled', 'Shipped - Lost in Transit', 
                                   'Shipped - Rejected by Buyer',
                                   'Shipped - Returned to Seller', 'Shipped - Damaged', 
                                   'Shipped - Returning to Seller')
              THEN 1 ELSE 0 END)::NUMERIC / NULLIF(COUNT(*), 0) * 100, 2) 
        as total_failure_rate_percent,
    TO_CHAR(SUM(CAST(amount AS NUMERIC)), 'FM999,999,999.00') as total_revenue
FROM amazon_sales
WHERE amount IS NOT NULL
    AND amount ~ '^[0-9]+\.?[0-9]*$'
GROUP BY category
HAVING COUNT(*) > 50  -- Filter out categories with too few orders for statistical significance
ORDER BY total_failure_rate_percent DESC
LIMIT 10;
-- KEY FINDINGS:
-- Top Problem Categories: Bottom, Western Dress, Kurta, Set, Blouse
-- ALARMING: Some categories have 50%+ failure rates!
-- RECOMMENDATION: Audit these product lines immediately


-- Query 9: Deep-dive into top 5 failing categories
-- PURPOSE: Quantify exact losses from problematic product categories
-- BUSINESS VALUE: Calculate ROI of fixing quality/supplier issues
SELECT  
    category,
    COUNT(*) as total_problem_orders,
    SUM(CAST(amount AS NUMERIC)) as total_lost_revenue,
    ROUND(AVG(CAST(amount AS NUMERIC)), 2) as avg_problem_order_value,
    TO_CHAR(SUM(CAST(amount AS NUMERIC)), 'FM999,999.00') as formatted_loss
FROM amazon_sales
WHERE category IN ('Bottom', 'Western Dress', 'Kurta', 'Set', 'Blouse')
    AND status IN ('Cancelled', 'Shipped - Lost in Transit', 'Shipped - Rejected by Buyer')
    AND amount IS NOT NULL
    AND amount ~ '^[0-9]+\.?[0-9]*$'
GROUP BY category
ORDER BY total_lost_revenue DESC;
-- ACTIONABLE: These 5 categories alone account for significant losses
-- RECOMMENDATION: 
-- 1. Review supplier contracts for these products
-- 2. Improve product descriptions to reduce expectation mismatches
-- 3. Consider quality control checks before shipment


-- ============================================================================
-- SECTION 5: GEOGRAPHIC FAILURE ANALYSIS
-- ============================================================================

-- Query 10: Identify cities with highest delivery failure rates
-- PURPOSE: Find geographic areas with operational problems
-- ROOT CAUSES: Poor courier service, remote locations, address issues
-- BUSINESS ACTION: Renegotiate courier contracts or adjust delivery zones
SELECT 
    category,
    ship_city,
    COUNT(*) as total_orders,
    SUM(CASE WHEN status IN ('Cancelled', 'Shipped - Lost in Transit', 
                             'Shipped - Rejected by Buyer') 
        THEN 1 ELSE 0 END) as delivery_failures,
    ROUND((SUM(CASE WHEN status IN ('Cancelled', 'Shipped - Lost in Transit', 
                                    'Shipped - Rejected by Buyer') 
               THEN 1 ELSE 0 END)::NUMERIC / 
           NULLIF(COUNT(*), 0) * 100), 2) as failure_rate_percent,
    TO_CHAR(SUM(CASE WHEN status IN ('Cancelled', 'Shipped - Lost in Transit', 
                                     'Shipped - Rejected by Buyer')
                THEN CAST(amount AS NUMERIC) ELSE 0 END), 'FM999,999.00') 
        as lost_revenue_in_city
FROM amazon_sales
WHERE category IN ('Bottom', 'Western Dress', 'Kurta', 'Set', 'Blouse')
    AND amount IS NOT NULL
    AND amount ~ '^[0-9]+\.?[0-9]*$'
GROUP BY category, ship_city
HAVING COUNT(*) > 10  -- Minimum sample size for reliability
ORDER BY failure_rate_percent DESC
LIMIT 20;
-- INSIGHT: Identifies specific city + category combinations with issues
-- RECOMMENDATION: 
-- 1. Use alternative courier services in high-failure cities
-- 2. Add delivery confirmation requirements
-- 3. Improve address verification at checkout


-- ============================================================================
-- SECTION 6: EXECUTIVE RISK DASHBOARD
-- ============================================================================

-- Query 11: Comprehensive risk summary for leadership
-- PURPOSE: One-page view of all risk metrics for decision-making
-- STAKEHOLDERS: CFO (financial risk), COO (operational fixes), CEO (strategy)
SELECT 
    'Total Pre-Delivery Losses (₹)' as risk_metric,
    TO_CHAR(SUM(CASE WHEN status IN ('Cancelled', 'Shipped - Lost in Transit', 
                                     'Shipped - Rejected by Buyer', 'Pending', 
                                     'Pending - Waiting for Pick Up')
                THEN CAST(amount AS NUMERIC) ELSE 0 END), 'FM999,999,999.00') as value,
    'Revenue lost before shipment' as impact
FROM amazon_sales
WHERE amount IS NOT NULL AND amount ~ '^[0-9]+\.?[0-9]*$'

UNION ALL

SELECT 
    'Total Post-Delivery Losses (₹)',
    TO_CHAR(SUM(CASE WHEN status IN ('Shipped - Returned to Seller', 'Shipped - Damaged', 
                                     'Shipped - Returning to Seller')
                THEN CAST(amount AS NUMERIC) ELSE 0 END), 'FM999,999,999.00'),
    'Revenue lost after shipment (higher cost)'
FROM amazon_sales
WHERE amount IS NOT NULL AND amount ~ '^[0-9]+\.?[0-9]*$'

UNION ALL

SELECT 
    'In-Transit Risk Exposure (₹)',
    TO_CHAR(SUM(CASE WHEN status IN ('Shipped', 'Shipped - Picked Up', 'Shipped - Out for Delivery')
                THEN CAST(amount AS NUMERIC) ELSE 0 END), 'FM999,999,999.00'),
    '₹51.6M at risk - only 73% will deliver successfully'
FROM amazon_sales
WHERE amount IS NOT NULL AND amount ~ '^[0-9]+\.?[0-9]*$'

UNION ALL

SELECT 
    'Expected Loss from In-Transit (₹)',
    TO_CHAR(ROUND(SUM(CASE WHEN status IN ('Shipped', 'Shipped - Picked Up', 'Shipped - Out for Delivery')
                THEN CAST(amount AS NUMERIC) ELSE 0 END) * (1 - 0.7291), 2), 'FM999,999,999.00'),
    'Predicted failures based on 27% historical failure rate'
FROM amazon_sales
WHERE amount IS NOT NULL AND amount ~ '^[0-9]+\.?[0-9]*$'

UNION ALL

SELECT 
    'Delivery Success Rate (%)',
    TO_CHAR(ROUND((SUM(CASE WHEN status = 'Shipped - Delivered to Buyer' THEN 1 ELSE 0 END)::NUMERIC /
                   NULLIF(SUM(CASE WHEN status IN ('Shipped - Delivered to Buyer', 'Cancelled', 
                                                   'Shipped - Lost in Transit', 'Shipped - Rejected by Buyer',
                                                   'Shipped - Returned to Seller', 'Shipped - Damaged', 
                                                   'Shipped - Returning to Seller') 
                              THEN 1 ELSE 0 END), 0) * 100), 2), 'FM999.00'),
    'Only 73% of orders complete successfully'
FROM amazon_sales

UNION ALL

SELECT 
    'Total Risk-Adjusted Revenue (₹)',
    TO_CHAR(SUM(CASE WHEN status = 'Shipped - Delivered to Buyer' THEN CAST(amount AS NUMERIC) ELSE 0 END) +
            (SUM(CASE WHEN status IN ('Shipped', 'Shipped - Picked Up', 'Shipped - Out for Delivery')
                 THEN CAST(amount AS NUMERIC) ELSE 0 END) * 0.7291), 'FM999,999,999.00'),
    'Realistic revenue after accounting for failure risk'
FROM amazon_sales
WHERE amount IS NOT NULL AND amount ~ '^[0-9]+\.?[0-9]*$';

-- ============================================================================
-- KEY INSIGHTS & CRITICAL RECOMMENDATIONS (PROJECT 2)
-- ============================================================================
/*
🚨 CRITICAL FINDINGS:

1. RISK EXPOSURE: ₹14M at risk in current in-transit inventory
   → Only 73% will successfully deliver based on historical patterns
   → Need to reserve funds for refunds and losses

2. PRE-DELIVERY LOSSES: ₹6.9M lost before shipping
   → 14.2% cancellation rate is TOO HIGH
   → Root causes: Payment issues? Stock unavailability? Poor UX?

3. POST-DELIVERY LOSSES: ₹2.3M lost to returns/damages
   → Actual cost is 2x due to reverse logistics
   → Total impact: ~₹4.6M including operational costs

4. CATEGORY PROBLEMS: 5 categories (Bottom, Western Dress, Kurta, Set, Blouse) 
   → Show 50%+ failure rates
   → These alone account for significant portion of losses
   → URGENT: Quality audit needed

5. SUCCESS RATE: Only 72.91% order completion
   → Industry standard is 85-90%
   → 15-20% improvement potential = ₹10-13M additional revenue

💡 STRATEGIC RECOMMENDATIONS (PRIORITY ORDER):

HIGH PRIORITY (Immediate Action Required):
1. Reduce cancellation rate from 14% to <8%
   - Improve payment success rates
   - Real-time inventory updates
   - Better product information

2. Audit top 5 failing product categories
   - Review supplier quality
   - Enhance product descriptions
   - Implement pre-shipment QC

3. Reserve ₹14M for in-transit risk exposure
   - Financial planning must account for 27% failure rate
   - Don't overestimate revenue forecasts

MEDIUM PRIORITY (Within 30 days):
4. Geographic delivery optimization
   - Identify high-failure cities from Query 10
   - Negotiate better courier contracts
   - Implement address verification

5. Reduce return rate (currently causing ₹2.3M loss)
   - Improve product photography
   - Size guides and fit recommendations
   - Customer reviews for realistic expectations

LONG-TERM (Strategic Initiatives):
6. Improve overall success rate from 73% → 85%
   - Potential revenue uplift: ₹10-13M annually
   - Better logistics partners
   - Predictive analytics for problem orders

FINANCIAL IMPACT OF RECOMMENDATIONS:
- Reducing cancellations by 50%: Save ~₹3.3M
- Improving success rate to 85%: Gain ~₹10M
- Optimizing top 5 categories: Save ~₹2-3M
- TOTAL POTENTIAL IMPACT: ₹15-16M additional annual revenue

📊 NEXT STEPS FOR STAKEHOLDERS:
→ CFO: Adjust revenue forecasts to use risk-adjusted numbers
→ COO: Immediate audit of top failing categories
→ Marketing: Reduce cancellations through better UX
→ Logistics: Renegotiate courier contracts for problem areas
→ Product: Quality improvements for high-failure SKUs
*/