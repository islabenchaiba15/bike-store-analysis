# Sales Intelligence: End-to-End Analytics Engineering Project
### Medallion Architecture · SQL Server Data Warehouse · Power BI Dashboard · Business Insights

---

## Executive Summary

This is a full end-to-end analytics engineering project that spans both the data engineering and data analysis disciplines. Raw CRM and ERP data was extracted from a PostgreSQL source, then structured through a three-layer Medallion Architecture (Bronze → Silver → Gold) inside a SQL Server data warehouse before being surfaced in an interactive Power BI dashboard. The project covers 60,407 transactions across six countries and four years (2010–2014), generating **$29.4M in total revenue** with a **52.5% blended gross margin**. It delivers strategic insights on product concentration risk, margin inefficiency, geographic over-reliance, and high-value customer segments — all actionable by business leadership.

---

## Business Problem

A retail business selling bikes, accessories, and clothing across six countries had no unified view of its sales performance. Data was fragmented across CRM and ERP systems, stored as raw CSV files with quality issues including duplicate records, mismatched keys, missing demographic data, and inconsistent country name formats.

**Without a clean, integrated data pipeline, the business could not:**

- Track revenue trends or identify demand seasonality reliably
- Understand which products, regions, or customer segments drove the most value
- Diagnose margin inefficiency or assess concentration risk across its product portfolio
- Make informed budget or expansion decisions backed by trustworthy data

This problem affected marketing teams, product managers, and senior leadership — all of whom were operating without a single source of truth.

---

## Methodology

### 1. Data Engineering — Medallion Architecture

The pipeline was built inside a **SQL Server data warehouse** using a three-layer Medallion Architecture, with data originally extracted from a **PostgreSQL source database** (CRM + ERP systems).

**Bronze Layer — Raw Ingestion**
- Object Type: Tables
- Load Strategy: Batch Processing · Full Load · Truncate & Insert
- Stored procedures handle ingestion from CSV source files
- No transformations applied — data preserved as-is for auditability

**Silver Layer — Cleaning & Standardisation**
- Object Type: Tables
- Load Strategy: Batch Processing · Full Load · Truncate & Insert
- Transformations applied via stored procedures:
  - Resolved negative sales/price values using `abs()` — confirmed sign errors, not refunds
  - Recalculated 20 rows where `sales ≠ qty × price` using unit price as source of truth
  - Parsed `YYYYMMDD` integer date encoding to proper datetime; invalid values → `NaT`
  - Deduplicated 102 product records — kept latest version per key based on start date
  - Flagged 200 rows with `product_end < product_start`; derived `is_current` flag
  - Resolved 3 mismatched key formats by stripping prefixes — achieved 100% join rate
  - Reduced gender nulls from 24.7% to under 2% via priority-merge from a second source
  - Standardised country name variants (USA/US → United States, DE → Germany)
  - Applied `.str.strip()` across all text fields to remove whitespace

**Gold Layer — Business-Ready Data**
- Object Type: Views (no load — query-time aggregation)
- Transformations: Data integration, aggregations, and business logic
- Data Model: Star Schema · Flat Table · Aggregated Table
- Consumed directly by Power BI and ad-hoc SQL queries

---

### 2. Data Analysis & Visualisation

**Exploratory Data Analysis (EDA)**
- Revenue trend analysis across years and quarters (2010–2014)
- Category and product line revenue breakdown
- Geographic revenue concentration by country
- Monthly seasonality analysis — identified strong year-end demand acceleration
- Customer segmentation by age group and gender
- Top 10 product performance ranked by revenue and average order value
- Gross margin analysis by category — identified the margin paradox between Bikes and Accessories

**Dashboard Design (Power BI — 3 Pages)**
- *Page 1 — Sales Performance:* 6 KPI cards, monthly revenue trend, category donut, country bar chart, top 10 products table
- *Page 2 — Customer Intelligence:* Age group revenue, gender split, geographic bubble map, customer cohort over time
- *Page 3 — Product Analysis:* Revenue vs margin scatter (quadrant view), subcategory treemap, product line grouped bar, product lifecycle Gantt
- Global filters persist across all pages: Date Range · Country · Category · Product Line

---

## Data Architecture

The diagram below illustrates the end-to-end high-level architecture of the project — from raw source systems through the three-layer SQL Server data warehouse to the final consumption layer.

![High Level Architecture](data_architecture.png)

> **Sources** (CRM + ERP CSV files) → **Bronze Layer** (Raw Data / Tables) → **Silver Layer** (Cleaned & Standardised / Tables) → **Gold Layer** (Business-Ready / Views) → **Consume** (Power BI · Ad-Hoc SQL · Machine Learning)

---

## Skills

- **Data Engineering** — Medallion Architecture (Bronze / Silver / Gold), ETL pipeline design, stored procedures
- **SQL** — Data extraction from PostgreSQL, transformation logic in SQL Server, Star Schema modelling
- **Data Cleaning** — Handling nulls, duplicates, type mismatches, key format inconsistencies, derived columns
- **Exploratory Data Analysis (EDA)** — Revenue trends, segmentation, seasonality, margin analysis
- **Data Visualisation** — Power BI dashboard design (KPI cards, line charts, donut charts, scatter plots, maps, matrix tables)
- **DAX** — Calculated measures for KPIs, YoY comparisons, margin percentages, dynamic filtering
- **Business Analysis** — Translating data patterns into strategic recommendations for product, marketing, and finance stakeholders
- **Data Storytelling** — Structuring findings into a structured report narrative from raw data to executive summary

---

## Results & Business Recommendations

### Key Findings

| Metric | Value |
|---|---|
| Total Revenue (2010–2014) | $29.4M |
| Total Orders | 27,659 |
| Average Order Value | $1,062 |
| Blended Gross Margin | 52.5% |
| Unique Customers | 18,484 |
| Active Products | 130 |
| Top Geography | US + Australia = 62% of revenue |
| Top Age Segment | 35–44 = 36.7% of revenue |
| 2013 YoY Growth | +180% vs 2011 |

### Business Recommendations

**1. Reduce Bike Revenue Concentration Risk**
Bikes generate 96.5% of total revenue ($28.3M) but carry only a 38.8% gross margin — 23 percentage points below Accessories. The business is over-reliant on a single category. Diversification is essential to long-term resilience.

**2. Prioritise Accessories as the Growth Engine**
Accessories hold a 61.9% gross margin but represent just 2.4% of revenue. Launching accessories attach-rate bundles at point of bike purchase is the single highest-ROI lever available. Even modest attach-rate improvements would meaningfully lift blended margin.

**3. Retain the 35–44 Customer Segment**
This age group accounts for 36.7% of revenue across 6,086 active customers. Targeted retention campaigns (loyalty programmes, lifecycle offers) should be prioritised for this cohort before scaling acquisition spend.

**4. Investigate the 2012 Revenue Cliff**
Revenue dropped 18% in 2012 versus 2011 with no documented root cause. Before committing further investment to geographic or product expansion, this structural risk must be understood and resolved.

**5. Expand Selectively in France and Germany**
The customer base already exists in both markets but revenue per customer is disproportionately low compared to the US and Australia. Targeted campaigns in these markets represent a lower-cost growth path than entering new geographies.

**6. Resolve Discontinued Product Revenue Dependency**
29% of revenue ($8.6M) originates from discontinued products with no restock path. A structured product succession and catalogue refresh plan is required to protect revenue in the medium term.

---

## Next Steps

- **Automate the ETL pipeline** — Schedule stored procedures using SQL Server Agent for incremental daily loads, removing the need for manual batch runs
- **Add incremental loading to the Bronze layer** — Replace full truncate-and-insert with CDC (Change Data Capture) or watermark-based incremental loads to improve pipeline efficiency at scale
- **Integrate predictive analytics** — Build a demand forecasting model on top of the Gold layer to anticipate seasonal peaks (particularly the December year-end surge) and optimise inventory
- **Customer Lifetime Value (CLV) modelling** — Extend the customer intelligence page with RFM scoring and CLV prediction to support targeted retention spend allocation
- **Data quality monitoring** — Implement automated data quality checks between Bronze and Silver layers with alerting on threshold breaches (e.g., null rate, row count variance, key mismatch rate)
- **Expand geographic coverage** — Ingest additional regional data sources to reduce the analytical blind spots in France, Germany, and Canada
- **Publish to Power BI Service** — Deploy the dashboard with row-level security (RLS) to enable self-service access across business units with appropriate data governance controls
