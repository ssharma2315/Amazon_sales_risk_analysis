)

📦 Amazon Sales Risk & Failure Analysis

A deep-dive into operational failures, lost revenue, and business risks across 128,976 Amazon orders using SQL & Power BI.

📊 Project Overview

This project analyzes operational risk, delivery failures, and revenue leakage using a real-world Amazon sales dataset containing 128,976 orders.

The goal is to uncover:

Why orders fail before or after delivery

Where revenue is being lost

Which product categories and regions contribute most to losses

How much “expected revenue” is realistic after accounting for risk

What actions can reduce cancellations, returns, and operational failures

Using PostgreSQL for data processing and Power BI for interactive dashboards, this project provides a complete end-to-end risk assessment framework.

🛠️ Tech Stack
Tool	Purpose
PostgreSQL	Complex SQL analysis, risk modeling, categorization
Power BI	Interactive dashboards (Risk Summary, Loss Drivers, Category Risk)
Excel	Initial data review & preprocessing
DAX	Supporting KPIs
📁 Dataset Overview

The dataset contains 128,976 Amazon orders with fields such as:

Order status

Category, SKU, styles

Order amount & quantity

Courier status

Shipping city/state

Pre- and post-delivery issues

A custom SQL schema was created to structure the data:

CREATE TABLE amazon_sales (
    index VARCHAR(10),
    Order_ID VARCHAR(50),
    Dates VARCHAR(15),
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
    Qty VARCHAR(10),
    currency VARCHAR(10),
    Amount VARCHAR(15),
    ship_states VARCHAR(50),
    ship_city VARCHAR(100),
    ship_postal_code VARCHAR(20),
    ship_country VARCHAR(50),
    promotions_ids TEXT,
    B2B VARCHAR(10),
    Fullfilled_by VARCHAR(100)
);
ALTER TABLE amazon_sales ADD COLUMN Country_name VARCHAR(100);

📌 What This Project Solves
🔍 Core Business Questions

How much revenue is lost before delivery?

How much revenue is lost after delivery?

What % of shipped orders genuinely deliver?

How much revenue is “at risk” right now?

Which product categories fail the most?

Which cities experience the highest delivery failures?

🧠 Key Insights (SQL Analysis)
🚨 1. Pre-Delivery Losses (Before Shipping)

Total Loss: ₹6.9M

Primary cause: Cancelled orders = 71% of losses

Other causes: Lost in transit, buyer rejection, pending pickups

⚠️ 2. Post-Delivery Losses (Returns & Damages)

Total Loss: ₹2.3M

Real cost ~2x due to: reverse logistics, packaging, restocking

Major reasons: Product damaged, returned to seller

📉 3. In-Transit Revenue Risk

Current in-transit revenue: ₹51.6M

Historical success rate: 72.91%

Expected loss: ₹14M

Meaning: 27% of all shipped orders historically fail

📦 4. Category Failure Rates

Highest failure categories:

Bottom

Western Dress

Kurta

Set

Blouse

Some categories showed 50%+ failure rates, indicating:

Quality issues

Incorrect product descriptions

Sizing/photo mismatch (common in apparel)

🌍 5. Geographic Failure Clusters

Cities with high delivery failure rates identified:
(shown in Power BI map)

Metro outskirts

Low-courier coverage regions

High-return clusters in apparel categories

📊 Power BI Dashboards

The project includes 3 professional dashboards, built from your screenshots.

🟦 1. Category Risk Analysis Dashboard

✔️ Failure comparison by category
✔️ Successful vs unsuccessful deliveries
✔️ Volume vs failure rate bubble chart

(your screenshot visuals: treemap, bar charts, bubbles)

🟥 2. Loss Drivers Dashboard

✔️ Pre-delivery vs Post-delivery losses
✔️ Losses by status
✔️ Category & source filters

(screenshot: donut charts + loss-by-status bar)

🟩 3. Executive Summary Dashboard

Includes top KPIs:

Total Risk-Adjusted Value

Delivery Success Rate

Pre-Delivery Losses

Post-Delivery Losses

Map of failure hotspots

Recommendations section

(your third screenshot)

📈 Risk-Adjusted Revenue Framework

This model calculates true revenue, not optimistic revenue.

Formula:

Actual Delivered Revenue  
+ (In-Transit Revenue × Historical Success Rate)


Result:

Reported: ₹69.6M

Realistic: ₹56.3M

Overestimation: ₹13.3M

🎯 Business Recommendations
🟢 HIGH PRIORITY

Reduce cancellation rate (14% → <8%)

Audit top failing product categories

Reserve funds for ₹14M at-risk revenue

Fix courier performance in problem cities

🟡 MEDIUM PRIORITY

Improve product descriptions & sizing guides

Enhance address validation

Use alternative courier partners for weak regions

🔵 LONG-TERM

Improve delivery success rate from 73% → 85%

Introduce pre-shipment quality checks

Predictive model for "likely to fail" orders