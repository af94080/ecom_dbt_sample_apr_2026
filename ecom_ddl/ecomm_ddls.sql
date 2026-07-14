-- =============================================================================
--  3-LAYER SNOWFLAKE DATA MODEL: E-COMMERCE ORDERS & PRODUCTS
--  Layer 1 : LANDING   (raw ingest, schema-on-write)
--  Layer 2 : WAREHOUSE (facts & dimensions, star schema)
--  Layer 3 : DATAMART  (aggregated, business-ready reporting)
-- =============================================================================

-- ---------------------------------------------------------------------------
-- DATABASE & SCHEMA SETUP
-- ---------------------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS ECOMM_DB;

CREATE SCHEMA IF NOT EXISTS ECOMM_DB.LANDING   COMMENT = 'Layer 1 – raw landing tables';
CREATE SCHEMA IF NOT EXISTS ECOMM_DB.WAREHOUSE  COMMENT = 'Layer 2 – facts and dimensions';
CREATE SCHEMA IF NOT EXISTS ECOMM_DB.DATAMART   COMMENT = 'Layer 3 – analytic reporting mart';




-- =============================================================================
-- LAYER 1 · LANDING
-- Raw tables that mirror source system payloads.
-- Columns are intentionally permissive (VARCHAR) to avoid load failures.
-- Metadata columns (_loaded_at, _source) are appended at ingestion time.
-- =============================================================================


-- 1.1 orders 

create or replace TABLE LND_ORDERS (
	ORDER_ID VARCHAR(36) NOT NULL,
	CUSTOMER_ID VARCHAR(36),
	STATUS VARCHAR(50),
	TOTAL_AMOUNT VARCHAR(50),
	ORDER_TS TIMESTAMP_NTZ(9),
	ORDER_DATE DATE,
	CHANNEL VARCHAR(50),
	_LOADED_AT TIMESTAMP_NTZ(9) DEFAULT CURRENT_TIMESTAMP(),
	_SOURCE VARCHAR(100) DEFAULT 'oms_api',
	ORDER_DISCOUNT FLOAT DEFAULT 0
);

-- 1.2 order items

create or replace TABLE LND_ORDER_ITEMS (
	ITEM_ID VARCHAR(36) NOT NULL,
	ORDER_ID VARCHAR(36),
	PRODUCT_ID VARCHAR(36),
	QUANTITY VARCHAR(20),
	UNIT_PRICE VARCHAR(50),
	DISCOUNT VARCHAR(50),
	_LOADED_AT TIMESTAMP_NTZ(9) DEFAULT CURRENT_TIMESTAMP(),
	_SOURCE VARCHAR(100) DEFAULT 'oms_api'
);

-- 1.3 customers

create or replace TABLE LND_CUSTOMERS (
	CUSTOMER_ID VARCHAR(36) NOT NULL,
	FIRST_NAME VARCHAR(100),
	LAST_NAME VARCHAR(100),
	EMAIL VARCHAR(255),
	SEGMENT VARCHAR(50),
	COUNTRY VARCHAR(100),
	CITY VARCHAR(100),
	SIGNUP_DATE DATE,
	_LOADED_AT TIMESTAMP_NTZ(9) DEFAULT CURRENT_TIMESTAMP(),
	_SOURCE VARCHAR(100) DEFAULT 'crm_api'
);

-- 1.4 products

create or replace TABLE LND_PRODUCTS (
	PRODUCT_ID VARCHAR(36) NOT NULL,
	SKU VARCHAR(100),
	NAME VARCHAR(255),
	CATEGORY VARCHAR(100),
	SUB_CATEGORY VARCHAR(100),
	COST_PRICE VARCHAR(50),
	LIST_PRICE VARCHAR(50),
	SUPPLIER_ID VARCHAR(36),
	_LOADED_AT TIMESTAMP_NTZ(9) DEFAULT CURRENT_TIMESTAMP(),
	_SOURCE VARCHAR(100) DEFAULT 'pim_api'
);

-- 1.5 suppliers

create or replace TABLE LND_SUPPLIERS (
	SUPPLIER_ID VARCHAR(36) NOT NULL,
	NAME VARCHAR(255),
	COUNTRY VARCHAR(100),
	CONTACT_EMAIL VARCHAR(255),
	_LOADED_AT TIMESTAMP_NTZ(9) DEFAULT CURRENT_TIMESTAMP(),
	_SOURCE VARCHAR(100) DEFAULT 'erp_api'
);

-- =============================================================================
-- LAYER 2 · WAREHOUSE  (Star Schema)
-- Cleaned, typed, conformed dimensions and a central fact table.
-- =============================================================================

-- ── Dimensions ──────────────────────────────────────────────────────────────

CREATE OR REPLACE TABLE ECOMM_DB.WAREHOUSE.DIM_DATE (
    date_key        INT           NOT NULL PRIMARY KEY,  -- YYYYMMDD integer
    full_date       DATE          NOT NULL,
    year            INT,
    quarter         INT,
    month           INT,
    month_name      VARCHAR(20),
    week            INT,
    day_of_week     INT,          -- 1=Mon … 7=Sun
    day_name        VARCHAR(20),
    is_weekend      BOOLEAN,
    is_holiday      BOOLEAN       DEFAULT FALSE
);

CREATE OR REPLACE TABLE ECOMM_DB.WAREHOUSE.DIM_CHANNEL (
    channel_key     VARCHAR(50)   NOT NULL PRIMARY KEY,
    channel_name    VARCHAR(100),
    channel_type    VARCHAR(50)   -- 'digital', 'physical', 'third_party'
);

CREATE OR REPLACE TABLE ECOMM_DB.WAREHOUSE.DIM_CUSTOMER (
    customer_id     VARCHAR(36)   NOT NULL PRIMARY KEY,
    full_name       VARCHAR(255),
    email           VARCHAR(255),
    segment         VARCHAR(50),
    country         VARCHAR(100),
    city            VARCHAR(100),
    signup_date     DATE,
    is_active       BOOLEAN       DEFAULT TRUE,
    _updated_at     TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

CREATE OR REPLACE TABLE ECOMM_DB.WAREHOUSE.DIM_PRODUCT (
    product_id      VARCHAR(36)   NOT NULL PRIMARY KEY,
    sku             VARCHAR(100),
    name            VARCHAR(255),
    category        VARCHAR(100),
    sub_category    VARCHAR(100),
    cost_price      NUMBER(18,4),
    list_price      NUMBER(18,4),
    supplier_name   VARCHAR(255),
    is_active       BOOLEAN       DEFAULT TRUE,
    _updated_at     TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- ── Fact Table ───────────────────────────────────────────────────────────────

CREATE OR REPLACE TABLE ECOMM_DB.WAREHOUSE.FACT_ORDER_ITEMS (
    order_item_sk   BIGINT        NOT NULL PRIMARY KEY AUTOINCREMENT,
    order_id        VARCHAR(36)   NOT NULL,
    item_id         VARCHAR(36)   NOT NULL,
    customer_id     VARCHAR(36)   REFERENCES ECOMM_DB.WAREHOUSE.DIM_CUSTOMER(customer_id),
    product_id      VARCHAR(36)   REFERENCES ECOMM_DB.WAREHOUSE.DIM_PRODUCT(product_id),
    date_key        INT           REFERENCES ECOMM_DB.WAREHOUSE.DIM_DATE(date_key),
    channel_key     VARCHAR(50)   REFERENCES ECOMM_DB.WAREHOUSE.DIM_CHANNEL(channel_key),
    order_status    VARCHAR(50),
    quantity        INT,
    unit_price      NUMBER(18,4),
    discount_amount NUMBER(18,4),
    gross_revenue   NUMBER(18,4)  AS (quantity * unit_price) VIRTUAL,
    net_revenue     NUMBER(18,4)  AS (quantity * unit_price - discount_amount) VIRTUAL,
    cost_of_goods   NUMBER(18,4),
    gross_margin    NUMBER(18,4)  AS (quantity * unit_price - discount_amount - cost_of_goods) VIRTUAL,
    _loaded_at      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- =============================================================================
-- LAYER 3 · DATAMART
-- Pre-aggregated, denormalised tables optimised for BI tools and dashboards.
-- =============================================================================

CREATE OR REPLACE TABLE ECOMM_DB.DATAMART.MART_SALES_SUMMARY (
    date_key              INT           NOT NULL,
    product_id            VARCHAR(36)   NOT NULL,
    customer_segment      VARCHAR(50),
    channel               VARCHAR(50),
    total_orders          INT,
    total_units_sold      INT,
    total_gross_revenue   NUMBER(18,2),
    total_net_revenue     NUMBER(18,2),
    total_cogs            NUMBER(18,2),
    total_gross_margin    NUMBER(18,2),
    margin_pct            NUMBER(8,4)   AS (
                              CASE WHEN total_net_revenue = 0 THEN NULL
                              ELSE total_gross_margin / total_net_revenue END
                          ) VIRTUAL,
    avg_order_value       NUMBER(18,2),
    _refreshed_at         TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (date_key, product_id, customer_segment, channel)
);

CREATE OR REPLACE TABLE ECOMM_DB.DATAMART.MART_CUSTOMER_LIFETIME (
    customer_id           VARCHAR(36)   NOT NULL PRIMARY KEY,
    full_name             VARCHAR(255),
    segment               VARCHAR(50),
    country               VARCHAR(100),
    total_orders          INT,
    total_units           INT,
    total_spend           NUMBER(18,2),
    avg_order_value       NUMBER(18,2),
    first_order_date      DATE,
    last_order_date       DATE,
    days_since_last_order INT,
    rfm_segment           VARCHAR(50),  -- 'Champions','Loyal','At Risk','Lost', etc.
    _refreshed_at         TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

CREATE OR REPLACE TABLE ECOMM_DB.DATAMART.MART_PRODUCT_PERFORMANCE (
    product_id            VARCHAR(36)   NOT NULL,
    date_key              INT           NOT NULL,
    product_name          VARCHAR(255),
    category              VARCHAR(100),
    sub_category          VARCHAR(100),
    units_sold            INT,
    revenue               NUMBER(18,2),
    cogs                  NUMBER(18,2),
    gross_margin          NUMBER(18,2),
    margin_pct            NUMBER(8,4),
    rank_in_category      INT,          -- daily rank by revenue within category
    _refreshed_at         TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (product_id, date_key)
);






