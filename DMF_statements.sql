-- ================================================================
-- COMPREHENSIVE DATA QUALITY MONITORING DEMO
-- Covers: System DMFs (all categories), Custom DMFs, Expectations,
--         Anomaly Detection, Notifications, Schema-level DMFs,
--         Scheduling, and Monitoring Queries
-- ================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE COMPUTE_WH;

CREATE OR REPLACE DATABASE dq_demo;
CREATE OR REPLACE SCHEMA dq_demo.ecommerce;
USE DATABASE dq_demo;
USE SCHEMA ecommerce;

-- ================================================================
-- SECTION 1: CREATE TABLES
-- ================================================================

CREATE OR REPLACE TABLE customers (
    customer_id     INT,
    first_name      VARCHAR(50),
    last_name       VARCHAR(50),
    email           VARCHAR(100),
    phone           VARCHAR(20),
    city            VARCHAR(50),
    state           VARCHAR(2),
    signup_date     DATE,
    is_active       BOOLEAN
);

CREATE OR REPLACE TABLE orders (
    order_id        INT,
    customer_id     INT,
    order_date      TIMESTAMP_LTZ,
    total_amount    DECIMAL(10,2),
    status          VARCHAR(20),
    shipping_city   VARCHAR(50),
    discount_pct    DECIMAL(5,2),
    notes           VARCHAR(200)
);

CREATE OR REPLACE TABLE products (
    product_id      INT,
    product_name    VARCHAR(100),
    category        VARCHAR(50),
    price           DECIMAL(10,2),
    stock_quantity  INT,
    sku             VARCHAR(30)
);

-- ================================================================
-- SECTION 2: INSERT SAMPLE DATA WITH INTENTIONAL QUALITY ISSUES
-- ================================================================

-- CUSTOMERS: includes NULLs, duplicates, blanks, untrimmed strings,
-- case violations, future dates, special characters
INSERT INTO customers VALUES
    (1, 'Alice', 'Smith', 'alice@example.com', '555-0101', 'New York', 'NY', '2023-01-15', TRUE),
    (2, 'Bob', 'Johnson', 'bob@example.com', '555-0102', 'Los Angeles', 'CA', '2023-02-20', TRUE),
    (3, 'Charlie', 'Williams', NULL, '555-0103', 'Chicago', 'IL', '2023-03-10', TRUE),
    (4, 'Diana', 'Brown', 'diana@example.com', NULL, NULL, 'TX', '2023-04-05', TRUE),
    (5, 'Eve', 'Davis', 'eve@example.com', '555-0105', 'Houston', 'TX', '2023-05-12', FALSE),
    (6, 'Frank', 'Miller', 'alice@example.com', '555-0106', 'Phoenix', 'AZ', '2023-06-18', TRUE),  -- duplicate email
    (7, 'Grace', 'Wilson', 'grace@example.com', '', 'San Antonio', 'TX', '2023-07-22', TRUE),      -- blank phone
    (8, 'Henry', 'Moore', 'henry@example.com', '555-0108', '  Dallas  ', 'TX', '2023-08-30', TRUE), -- untrimmed city
    (9, 'Ivy', 'Taylor', 'ivy@example.com', '555-0109', 'San Jose', 'CA', '2023-09-14', NULL),
    (10, 'JACK', 'ANDERSON', 'jack@example.com', '555-0110', 'austin', 'TX', '2023-10-01', TRUE),  -- case violations
    (11, 'Kate', 'Thomas', NULL, NULL, 'Denver', 'CO', '2023-11-05', TRUE),                        -- NULL email
    (12, 'Leo', 'Jackson', 'leo@example.com', '555-0112', 'Seattle', 'WA', '2023-12-20', TRUE),
    (13, 'Mia', 'White', 'mia@example.com', '555@#$%', 'Portland', 'OR', '2024-01-10', TRUE),     -- special chars in phone
    (14, 'Nick', 'Harris', 'nick@example.com', '555-0114', 'Miami', 'FL', '2024-02-28', TRUE),
    (15, 'Olivia', 'Martin', 'olivia@example.com', '555-0115', 'Atlanta', 'GA', '2027-06-15', TRUE), -- future signup date
    (16, 'Paul', 'Garcia', 'paul@example.com', '555-0116', '', 'NV', '2024-04-10', TRUE),          -- blank city
    (17, 'Quinn', 'Martinez', 'quinn@example.com', '555-0117', 'Boston', 'MA', '2024-05-20', TRUE),
    (18, 'Rose', 'Robinson', 'rose@example.com', '555-0118', 'Nashville', 'TN', '2024-06-01', FALSE),
    (19, 'Sam', 'Clark', 'sam@example.com', NULL, 'Detroit', 'MI', '2024-07-15', TRUE),
    (20, 'Tina', 'Lewis', 'alice@example.com', '555-0120', 'Minneapolis', 'MN', '2024-08-01', TRUE), -- duplicate email (3rd)
    (21, 'Uma', 'Lee', NULL, '555-0121', 'Charlotte', 'NC', '2024-08-10', TRUE),                   -- NULL email
    (22, 'Vera', 'Walker', 'vera@example.com', '555-0122', 'Columbus', 'OH', '2024-09-01', TRUE),
    (23, 'Will', 'Hall', 'will@example.com', '555-0123', '  Raleigh ', 'NC', '2024-09-15', TRUE),  -- untrimmed city
    (24, 'Xena', 'Allen', 'xena@example.com', '555-0124', 'Tampa', 'FL', '2024-10-01', TRUE),
    (25, 'Yuri', 'Young', 'yuri@example.com', '555-0125', 'Pittsburgh', 'PA', '2024-10-20', TRUE);

-- ORDERS: includes NULLs, negative amounts, invalid statuses,
-- orphan customer_ids, future dates, extreme discounts
INSERT INTO orders VALUES
    (1001, 1, '2024-01-15 10:30:00', 150.00, 'completed', 'New York', 5.00, 'Express delivery'),
    (1002, 2, '2024-01-16 14:20:00', 89.99, 'completed', 'Los Angeles', 10.00, NULL),
    (1003, 3, '2024-01-17 09:15:00', -25.00, 'completed', 'Chicago', 0.00, 'Refund issued'),       -- negative amount
    (1004, 4, '2024-01-18 16:45:00', 200.00, 'shipped', 'Houston', 15.00, NULL),
    (1005, 5, '2024-01-19 11:00:00', 45.50, 'pending', 'Houston', 0.00, NULL),
    (1006, NULL, '2024-01-20 13:30:00', 320.00, 'completed', 'Phoenix', 20.00, NULL),              -- NULL customer_id
    (1007, 7, '2024-01-21 08:00:00', 75.00, NULL, 'San Antonio', 5.00, 'Gift wrapped'),            -- NULL status
    (1008, 8, '2024-01-22 15:10:00', 180.00, 'completed', 'Dallas', 10.00, NULL),
    (1009, 9, '2024-01-23 12:45:00', 0.00, 'cancelled', 'San Jose', 0.00, 'Customer cancelled'),   -- zero amount
    (1010, 10, '2024-01-24 17:20:00', 95.00, 'INVALID', 'Austin', 5.00, NULL),                     -- invalid status
    (1011, 11, '2024-02-01 09:30:00', 250.00, 'completed', 'Denver', 8.00, NULL),
    (1012, 12, '2024-02-05 14:00:00', 130.00, 'shipped', 'Seattle', 12.00, '  Priority  '),        -- untrimmed notes
    (1013, 999, '2024-02-10 10:15:00', 60.00, 'pending', 'Portland', 0.00, NULL),                  -- orphan customer_id
    (1014, 14, '2024-02-15 16:30:00', -10.00, 'completed', 'Miami', 75.00, NULL),                  -- negative amount + excessive discount
    (1015, 15, '2027-03-01 11:45:00', 175.00, 'shipped', 'Atlanta', 5.00, NULL),                   -- future order date
    (1016, 16, '2024-03-05 08:20:00', 88.00, 'completed', 'Las Vegas', 10.00, NULL),
    (1017, 17, '2024-03-10 13:00:00', 210.00, NULL, 'Boston', 0.00, NULL),                         -- NULL status
    (1018, 18, '2024-03-15 15:45:00', 55.00, 'completed', 'Nashville', 5.00, NULL),
    (1019, 19, '2024-03-20 09:00:00', 420.00, 'shipped', 'Detroit', -5.00, NULL),                  -- negative discount
    (1020, 20, '2024-03-25 12:30:00', 99.99, 'completed', 'Minneapolis', 10.00, NULL),
    (1021, NULL, '2024-04-01 10:00:00', 150.00, 'pending', 'Charlotte', 0.00, NULL),               -- NULL customer_id
    (1022, 22, '2024-04-05 14:15:00', 275.00, 'completed', 'Columbus', 15.00, NULL),
    (1023, 23, '2024-04-10 16:00:00', 85.00, 'shipped', 'Raleigh', 5.00, NULL),
    (1024, 24, '2024-04-15 11:30:00', 190.00, 'completed', 'Tampa', 10.00, NULL),
    (1025, 25, '2024-04-20 09:45:00', 310.00, 'completed', 'Pittsburgh', 8.00, NULL);

-- PRODUCTS: includes negative prices, zero stock, duplicates
INSERT INTO products VALUES
    (1, 'Wireless Mouse', 'Electronics', 29.99, 150, 'ELEC-001'),
    (2, 'USB-C Cable', 'Electronics', 12.99, 500, 'ELEC-002'),
    (3, 'Laptop Stand', 'Accessories', 49.99, 75, 'ACC-001'),
    (4, 'Mechanical Keyboard', 'Electronics', 89.99, 200, 'ELEC-003'),
    (5, 'Monitor Light', 'Accessories', -15.00, 0, 'ACC-002'),          -- negative price, zero stock
    (6, 'Webcam HD', 'Electronics', 59.99, 100, 'ELEC-004'),
    (7, 'Desk Mat', 'Accessories', 24.99, 300, 'ACC-003'),
    (8, 'USB Hub', 'Electronics', 34.99, -10, 'ELEC-005'),             -- negative stock
    (9, 'Phone Stand', 'Accessories', 19.99, 250, 'ACC-004'),
    (10, 'Wireless Mouse', 'Electronics', 29.99, 150, 'ELEC-001'),    -- duplicate product
    (11, 'Bluetooth Speaker', 'Audio', 79.99, 80, 'AUD-001'),
    (12, 'Noise Cancelling Headphones', 'Audio', 199.99, 45, 'AUD-002'),
    (13, 'Portable Charger', 'Electronics', 0.00, 200, 'ELEC-006'),   -- zero price
    (14, 'Screen Protector', 'Accessories', 9.99, 1000, ''),           -- blank SKU
    (15, 'Smart Watch', 'Wearables', 299.99, 60, 'WEAR-001');


-- ================================================================
-- SECTION 3: SET DMF SCHEDULES
-- ================================================================

-- Using a cron schedule (required for ANOMALY_DETECTION to work;
-- TRIGGER_ON_CHANGES is incompatible with anomaly detection)
ALTER TABLE customers SET DATA_METRIC_SCHEDULE = '5 MINUTE';
ALTER TABLE orders SET DATA_METRIC_SCHEDULE = '5 MINUTE';
ALTER TABLE products SET DATA_METRIC_SCHEDULE = '5 MINUTE';


-- ================================================================
-- SECTION 4: SYSTEM DMFs - ACCURACY CATEGORY
-- ================================================================

-- NULL_COUNT: count of NULLs in critical columns
ALTER TABLE customers ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT ON (email);
ALTER TABLE customers ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT ON (phone);
ALTER TABLE customers ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT ON (city);
ALTER TABLE orders ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT ON (customer_id);
ALTER TABLE orders ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT ON (status);

-- NULL_PERCENT: percentage of NULLs
ALTER TABLE customers ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_PERCENT ON (phone);

-- BLANK_COUNT: count of blank/empty strings
ALTER TABLE customers ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.BLANK_COUNT ON (city);
ALTER TABLE customers ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.BLANK_COUNT ON (phone);
ALTER TABLE products ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.BLANK_COUNT ON (sku);

-- BLANK_PERCENT: percentage of blanks
ALTER TABLE products ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.BLANK_PERCENT ON (sku);

-- NEGATIVE_COUNT: negative values in numeric columns
ALTER TABLE orders ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NEGATIVE_COUNT ON (total_amount);
ALTER TABLE orders ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NEGATIVE_COUNT ON (discount_pct);
ALTER TABLE products ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NEGATIVE_COUNT ON (price);
ALTER TABLE products ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NEGATIVE_COUNT ON (stock_quantity);

-- NEGATIVE_PERCENT
ALTER TABLE orders ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NEGATIVE_PERCENT ON (total_amount);

-- FUTURE_TIMESTAMP_COUNT: dates in the future
ALTER TABLE customers ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.FUTURE_TIMESTAMP_COUNT ON (signup_date);
ALTER TABLE orders ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.FUTURE_TIMESTAMP_COUNT ON (order_date);

-- UNTRIMMED_STRING_COUNT: leading/trailing whitespace
ALTER TABLE customers ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.UNTRIMMED_STRING_COUNT ON (city);
ALTER TABLE orders ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.UNTRIMMED_STRING_COUNT ON (notes);

-- SPECIAL_CHARACTER_COUNT: non-alphanumeric characters
ALTER TABLE customers ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.SPECIAL_CHARACTER_COUNT ON (phone);

-- CASE_FORMAT_VIOLATION_COUNT: inconsistent casing
ALTER TABLE customers ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.CASE_FORMAT_VIOLATION_COUNT ON (first_name);
ALTER TABLE customers ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.CASE_FORMAT_VIOLATION_COUNT ON (city);

-- ZERO_COUNT: zeroes in numeric columns
ALTER TABLE orders ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.ZERO_COUNT ON (total_amount);
ALTER TABLE products ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.ZERO_COUNT ON (price);


-- ================================================================
-- SECTION 5: SYSTEM DMFs - UNIQUENESS CATEGORY
-- ================================================================

-- DUPLICATE_COUNT
ALTER TABLE customers ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.DUPLICATE_COUNT ON (email);
ALTER TABLE customers ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.DUPLICATE_COUNT ON (customer_id);
ALTER TABLE products ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.DUPLICATE_COUNT ON (sku);

-- UNIQUE_COUNT
ALTER TABLE customers ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.UNIQUE_COUNT ON (email);
ALTER TABLE orders ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.UNIQUE_COUNT ON (status);
ALTER TABLE products ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.UNIQUE_COUNT ON (category);

-- ACCEPTED_VALUES: validate allowed values
ALTER TABLE orders ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.ACCEPTED_VALUES ON (
    status, status -> status IN ('pending', 'shipped', 'completed', 'cancelled', 'returned'));


-- ================================================================
-- SECTION 6: SYSTEM DMFs - VOLUME CATEGORY
-- ================================================================

ALTER TABLE customers ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.ROW_COUNT ON ()
    ANOMALY_DETECTION = TRUE;

ALTER TABLE orders ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.ROW_COUNT ON ()
    ANOMALY_DETECTION = TRUE;

ALTER TABLE products ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.ROW_COUNT ON ()
    ANOMALY_DETECTION = TRUE;


-- ================================================================
-- SECTION 7: SYSTEM DMFs - FRESHNESS CATEGORY
-- ================================================================

ALTER TABLE orders ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.FRESHNESS ON (order_date)
    ANOMALY_DETECTION = TRUE;

ALTER TABLE customers ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.FRESHNESS ON (signup_date);


-- ================================================================
-- SECTION 8: SYSTEM DMFs - STATISTICS CATEGORY
-- ================================================================

-- Numeric statistics on order amounts
ALTER TABLE orders ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.AVG ON (total_amount);
ALTER TABLE orders ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.MIN ON (total_amount);
ALTER TABLE orders ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.MAX ON (total_amount);
ALTER TABLE orders ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.MEDIAN ON (total_amount);
ALTER TABLE orders ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.STDDEV ON (total_amount);

-- Product price statistics
ALTER TABLE products ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.AVG ON (price);
ALTER TABLE products ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.MIN ON (price);
ALTER TABLE products ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.MAX ON (price);

-- String length stats
ALTER TABLE customers ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.STRING_LENGTH_AVG ON (email);
ALTER TABLE customers ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.STRING_LENGTH_MAX ON (email);
ALTER TABLE customers ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.STRING_LENGTH_MIN ON (email);


-- ================================================================
-- SECTION 9: SYSTEM DMFs - SCHEMA CATEGORY
-- ================================================================

ALTER TABLE customers ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.SCHEMA_CHANGE_COUNT ON ();
ALTER TABLE orders ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.SCHEMA_CHANGE_COUNT ON ();


-- ================================================================
-- SECTION 10: CUSTOM DMFs
-- ================================================================

-- Custom DMF: Referential integrity (orphan orders with no matching customer)
CREATE OR REPLACE DATA METRIC FUNCTION dq_demo.ecommerce.orphan_order_count(
    ARG_T TABLE(ARG_C INT)
)
RETURNS NUMBER
AS
$$
    SELECT COUNT(*)
    FROM ARG_T
    WHERE ARG_C IS NOT NULL
      AND ARG_C NOT IN (SELECT customer_id FROM dq_demo.ecommerce.customers)
$$;

ALTER TABLE orders
    ADD DATA METRIC FUNCTION dq_demo.ecommerce.orphan_order_count ON (customer_id);

-- Custom DMF: Negative amounts (business rule: amounts should never be negative)
CREATE OR REPLACE DATA METRIC FUNCTION dq_demo.ecommerce.negative_amount_count(
    ARG_T TABLE(ARG_C DECIMAL(10,2))
)
RETURNS NUMBER
AS
$$
    SELECT COUNT(*) FROM ARG_T WHERE ARG_C < 0
$$;

ALTER TABLE orders
    ADD DATA METRIC FUNCTION dq_demo.ecommerce.negative_amount_count ON (total_amount);

-- Custom DMF: Invalid discount range (must be 0-50%)
CREATE OR REPLACE DATA METRIC FUNCTION dq_demo.ecommerce.invalid_discount_count(
    ARG_T TABLE(ARG_C DECIMAL(5,2))
)
RETURNS NUMBER
AS
$$
    SELECT COUNT(*) FROM ARG_T WHERE ARG_C < 0 OR ARG_C > 50
$$;

ALTER TABLE orders
    ADD DATA METRIC FUNCTION dq_demo.ecommerce.invalid_discount_count ON (discount_pct);

-- Custom DMF: Email format validation (basic check for @ and .)
CREATE OR REPLACE DATA METRIC FUNCTION dq_demo.ecommerce.invalid_email_count(
    ARG_T TABLE(ARG_C VARCHAR)
)
RETURNS NUMBER
AS
$$
    SELECT COUNT(*)
    FROM ARG_T
    WHERE ARG_C IS NOT NULL
      AND (ARG_C NOT LIKE '%_@_%.__%')
$$;

ALTER TABLE customers
    ADD DATA METRIC FUNCTION dq_demo.ecommerce.invalid_email_count ON (email);


-- ================================================================
-- SECTION 11: EXPECTATIONS (define what "good" looks like)
-- ================================================================

-- Completeness: email NULLs should be < 15% (max 3 out of 25)
ALTER TABLE customers
    MODIFY DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT ON (email)
    ADD EXPECTATION max_null_emails (VALUE <= 3);

-- Completeness: order status must never be NULL
ALTER TABLE orders
    MODIFY DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT ON (status)
    ADD EXPECTATION status_always_present (VALUE = 0);

-- Completeness: customer_id on orders must never be NULL
ALTER TABLE orders
    MODIFY DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT ON (customer_id)
    ADD EXPECTATION no_orphan_nulls (VALUE = 0);

-- Uniqueness: no duplicate emails
ALTER TABLE customers
    MODIFY DATA METRIC FUNCTION SNOWFLAKE.CORE.DUPLICATE_COUNT ON (email)
    ADD EXPECTATION no_duplicate_emails (VALUE = 0);

-- Accuracy: no negative order amounts
ALTER TABLE orders
    MODIFY DATA METRIC FUNCTION SNOWFLAKE.CORE.NEGATIVE_COUNT ON (total_amount)
    ADD EXPECTATION no_negative_amounts (VALUE = 0);

-- Accuracy: no future order dates
ALTER TABLE orders
    MODIFY DATA METRIC FUNCTION SNOWFLAKE.CORE.FUTURE_TIMESTAMP_COUNT ON (order_date)
    ADD EXPECTATION no_future_orders (VALUE = 0);

-- Accuracy: no future signup dates
ALTER TABLE customers
    MODIFY DATA METRIC FUNCTION SNOWFLAKE.CORE.FUTURE_TIMESTAMP_COUNT ON (signup_date)
    ADD EXPECTATION no_future_signups (VALUE = 0);

-- Volume: tables should have at least 10 rows
ALTER TABLE customers
    MODIFY DATA METRIC FUNCTION SNOWFLAKE.CORE.ROW_COUNT ON ()
    ADD EXPECTATION min_customer_count (VALUE >= 10);

ALTER TABLE orders
    MODIFY DATA METRIC FUNCTION SNOWFLAKE.CORE.ROW_COUNT ON ()
    ADD EXPECTATION min_order_count (VALUE >= 10);

-- Accuracy: all statuses must be valid values
ALTER TABLE orders
    MODIFY DATA METRIC FUNCTION SNOWFLAKE.CORE.ACCEPTED_VALUES ON (
        status, status -> status IN ('pending', 'shipped', 'completed', 'cancelled', 'returned'))
    ADD EXPECTATION all_statuses_valid (VALUE = 0);

-- Custom: no orphan orders
ALTER TABLE orders
    MODIFY DATA METRIC FUNCTION dq_demo.ecommerce.orphan_order_count ON (customer_id)
    ADD EXPECTATION no_orphan_orders (VALUE = 0);

-- Custom: no negative amounts
ALTER TABLE orders
    MODIFY DATA METRIC FUNCTION dq_demo.ecommerce.negative_amount_count ON (total_amount)
    ADD EXPECTATION amounts_non_negative (VALUE = 0);

-- Custom: all discounts in valid range
ALTER TABLE orders
    MODIFY DATA METRIC FUNCTION dq_demo.ecommerce.invalid_discount_count ON (discount_pct)
    ADD EXPECTATION discounts_in_range (VALUE = 0);

-- Custom: all emails properly formatted
ALTER TABLE customers
    MODIFY DATA METRIC FUNCTION dq_demo.ecommerce.invalid_email_count ON (email)
    ADD EXPECTATION all_emails_valid (VALUE = 0);

-- Products: no negative prices
ALTER TABLE products
    MODIFY DATA METRIC FUNCTION SNOWFLAKE.CORE.NEGATIVE_COUNT ON (price)
    ADD EXPECTATION no_negative_prices (VALUE = 0);

-- Products: no negative stock
ALTER TABLE products
    MODIFY DATA METRIC FUNCTION SNOWFLAKE.CORE.NEGATIVE_COUNT ON (stock_quantity)
    ADD EXPECTATION no_negative_stock (VALUE = 0);


-- ================================================================
-- SECTION 12: NOTIFICATIONS SETUP
-- Replace 'your.email@example.com' with your verified Snowflake email
-- ================================================================

-- Uncomment and update with your email to enable notifications:
/*
CREATE OR REPLACE NOTIFICATION INTEGRATION dq_email_notifications
    TYPE = EMAIL
    ENABLED = TRUE
    ALLOWED_RECIPIENTS = ('your.email@example.com');

GRANT MANAGE DATA QUALITY ON ACCOUNT TO ROLE ACCOUNTADMIN;
GRANT USAGE ON INTEGRATION dq_email_notifications TO ROLE ACCOUNTADMIN;

ALTER DATABASE dq_demo SET DATA_QUALITY_MONITORING_SETTINGS =
$$
notification:
  enabled: TRUE
  integrations:
    - DQ_EMAIL_NOTIFICATIONS
  cooldown_hours: 1
  metadata_included: TRUE
$$;
*/


-- ================================================================
-- SECTION 13: TRIGGER INITIAL DMF EVALUATION
-- Inserting/updating data triggers DMFs since schedule = TRIGGER_ON_CHANGES
-- ================================================================

-- Small update to trigger evaluation on all tables
UPDATE customers SET is_active = is_active WHERE customer_id = 1;
UPDATE orders SET notes = notes WHERE order_id = 1001;
UPDATE products SET stock_quantity = stock_quantity WHERE product_id = 1;


-- ================================================================
-- SECTION 14: MONITORING QUERIES
-- Run these after ~5 minutes to see results in the dashboard
-- ================================================================

-- 14a. Check DMF associations and their status
SELECT *
FROM TABLE(
    INFORMATION_SCHEMA.DATA_METRIC_FUNCTION_REFERENCES(
        REF_ENTITY_NAME => 'dq_demo.ecommerce.customers',
        REF_ENTITY_DOMAIN => 'TABLE'
    )
);

SELECT *
FROM TABLE(
    INFORMATION_SCHEMA.DATA_METRIC_FUNCTION_REFERENCES(
        REF_ENTITY_NAME => 'dq_demo.ecommerce.orders',
        REF_ENTITY_DOMAIN => 'TABLE'
    )
);

SELECT *
FROM TABLE(
    INFORMATION_SCHEMA.DATA_METRIC_FUNCTION_REFERENCES(
        REF_ENTITY_NAME => 'dq_demo.ecommerce.products',
        REF_ENTITY_DOMAIN => 'TABLE'
    )
);

-- 14b. View DMF results (available after evaluation completes)
SELECT
    measurement_time,
    metric_database,
    metric_schema,
    metric_name,
    table_name,
    argument_names,
    value
FROM SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_RESULTS
WHERE table_database = 'DQ_DEMO'
ORDER BY measurement_time DESC
LIMIT 50;

-- 14c. Check expectation violations
SELECT *
FROM TABLE(
    SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_EXPECTATION_STATUS(
        REF_ENTITY_NAME => 'DQ_DEMO.ECOMMERCE.CUSTOMERS',
        REF_ENTITY_DOMAIN => 'TABLE'
    )
)
ORDER BY measurement_time DESC;

SELECT *
FROM TABLE(
    SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_EXPECTATION_STATUS(
        REF_ENTITY_NAME => 'DQ_DEMO.ECOMMERCE.ORDERS',
        REF_ENTITY_DOMAIN => 'TABLE'
    )
)
ORDER BY measurement_time DESC;

-- 14d. Quick test: call DMFs directly to preview values (no schedule needed)
SELECT SNOWFLAKE.CORE.NULL_COUNT(SELECT email FROM customers) AS null_email_count;
SELECT SNOWFLAKE.CORE.DUPLICATE_COUNT(SELECT email FROM customers) AS duplicate_email_count;
SELECT SNOWFLAKE.CORE.NEGATIVE_COUNT(SELECT total_amount FROM orders) AS negative_amount_count;
SELECT SNOWFLAKE.CORE.FUTURE_TIMESTAMP_COUNT(SELECT order_date FROM orders) AS future_order_count;
-- ACCEPTED_VALUES cannot be called directly; use SYSTEM$DATA_METRIC_SCAN instead:
-- SELECT * FROM TABLE(SYSTEM$DATA_METRIC_SCAN(REF_ENTITY_NAME => 'DQ_DEMO.ECOMMERCE.ORDERS', METRIC_NAME => 'SNOWFLAKE.CORE.ACCEPTED_VALUES'));
-- ROW_COUNT cannot be called directly (takes zero-column table arg); use COUNT(*) instead:
SELECT COUNT(*) AS customer_row_count FROM customers;
SELECT SNOWFLAKE.CORE.BLANK_COUNT(SELECT city FROM customers) AS blank_city_count;
SELECT SNOWFLAKE.CORE.UNTRIMMED_STRING_COUNT(SELECT city FROM customers) AS untrimmed_city_count;

-- 14e. Check anomaly detection status
SELECT *
FROM SNOWFLAKE.LOCAL.DATA_QUALITY_MONITORING_ANOMALY_DETECTION_STATUS
WHERE table_database = 'DQ_DEMO'
ORDER BY scheduled_time DESC
LIMIT 20;

-- 14f. Evaluate all expectations at once
SELECT * FROM TABLE(SYSTEM$EVALUATE_DATA_QUALITY_EXPECTATIONS('DQ_DEMO.ECOMMERCE.ORDERS'));

SELECT * FROM TABLE(SYSTEM$EVALUATE_DATA_QUALITY_EXPECTATIONS('DQ_DEMO.ECOMMERCE.CUSTOMERS'));


----

-- Note: There is no "EXECUTE DATA METRIC FUNCTION" command.
-- DMFs run automatically based on the DATA_METRIC_SCHEDULE setting (60 MINUTE).
-- To see results immediately, use the direct DMF calls in section 14d above,
-- or use SYSTEM$EVALUATE_DATA_QUALITY_EXPECTATIONS in section 14f.


-- ================================================================
-- SECTION 15: AUTOMATIC DATA QUALITY INSIGHTS
-- ================================================================
-- Snowflake automatically monitors "popular" tables (based on query activity)
-- for ROW_COUNT and FRESHNESS anomalies — no DMF setup required.
-- Results appear in: SNOWFLAKE.LOCAL.AUTOMATIC_DATA_QUALITY_MONITORING_RESULTS
--
-- To make tables eligible for automatic insights:
-- 1. They need consistent query activity (reads)
-- 2. They need data changes (inserts/updates) to establish baseline patterns
-- 3. Snowflake requires ~2 weeks of activity to train the anomaly model
--
-- Below we generate query activity and simulate data patterns to accelerate
-- table popularity and trigger automatic monitoring.

-- 15a. Grant the required role to view automatic insights
--GRANT DATABASE ROLE SNOWFLAKE.DATA_QUALITY_MONITORING_VIEWER TO ROLE ACCOUNTADMIN;

-- 15b. Generate query activity on existing tables (makes them "popular")
-- Run these queries multiple times over several days to build up popularity signals
SELECT COUNT(*) FROM dq_demo.ecommerce.customers WHERE is_active = TRUE;
SELECT AVG(total_amount), COUNT(*) FROM dq_demo.ecommerce.orders WHERE status = 'completed';
SELECT category, SUM(stock_quantity) FROM dq_demo.ecommerce.products GROUP BY category;
SELECT c.first_name, COUNT(o.order_id)
FROM dq_demo.ecommerce.customers c
JOIN dq_demo.ecommerce.orders o ON c.customer_id = o.customer_id
GROUP BY c.first_name;
SELECT * FROM dq_demo.ecommerce.orders WHERE total_amount > 200;
SELECT * FROM dq_demo.ecommerce.products WHERE stock_quantity < 50;

-- 15c. Create a high-activity table that simulates a pipeline with volume changes
-- This will help trigger automatic volume anomaly detection
CREATE OR REPLACE TABLE dq_demo.ecommerce.daily_transactions (
    txn_id          INT AUTOINCREMENT,
    txn_date        DATE,
    customer_id     INT,
    product_id      INT,
    quantity        INT,
    amount          DECIMAL(10,2),
    payment_method  VARCHAR(20),
    region          VARCHAR(20)
);

-- Insert historical data to establish a baseline (simulating 30 days of consistent volume)
INSERT INTO dq_demo.ecommerce.daily_transactions (txn_date, customer_id, product_id, quantity, amount, payment_method, region)
SELECT
    DATEADD('day', -seq4(), CURRENT_DATE()) AS txn_date,
    UNIFORM(1, 25, RANDOM()) AS customer_id,
    UNIFORM(1, 15, RANDOM()) AS product_id,
    UNIFORM(1, 5, RANDOM()) AS quantity,
    ROUND(UNIFORM(10, 500, RANDOM())::DECIMAL(10,2), 2) AS amount,
    CASE UNIFORM(1, 4, RANDOM())
        WHEN 1 THEN 'credit_card'
        WHEN 2 THEN 'debit_card'
        WHEN 3 THEN 'paypal'
        ELSE 'bank_transfer'
    END AS payment_method,
    CASE UNIFORM(1, 4, RANDOM())
        WHEN 1 THEN 'North'
        WHEN 2 THEN 'South'
        WHEN 3 THEN 'East'
        ELSE 'West'
    END AS region
FROM TABLE(GENERATOR(ROWCOUNT => 3000));

-- Now simulate a sudden volume SPIKE (today's data is 10x normal)
-- This pattern triggers volume anomaly detection in automatic insights
INSERT INTO dq_demo.ecommerce.daily_transactions (txn_date, customer_id, product_id, quantity, amount, payment_method, region)
SELECT
    CURRENT_DATE() AS txn_date,
    UNIFORM(1, 25, RANDOM()) AS customer_id,
    UNIFORM(1, 15, RANDOM()) AS product_id,
    UNIFORM(1, 5, RANDOM()) AS quantity,
    ROUND(UNIFORM(10, 500, RANDOM())::DECIMAL(10,2), 2) AS amount,
    CASE UNIFORM(1, 4, RANDOM())
        WHEN 1 THEN 'credit_card'
        WHEN 2 THEN 'debit_card'
        WHEN 3 THEN 'paypal'
        ELSE 'bank_transfer'
    END AS payment_method,
    CASE UNIFORM(1, 4, RANDOM())
        WHEN 1 THEN 'North'
        WHEN 2 THEN 'South'
        WHEN 3 THEN 'East'
        ELSE 'West'
    END AS region
FROM TABLE(GENERATOR(ROWCOUNT => 1000));

-- Set schedule and enable anomaly detection on this table
ALTER TABLE dq_demo.ecommerce.daily_transactions SET DATA_METRIC_SCHEDULE = '5 MINUTE';

-- Drop existing DMFs first to make script re-runnable
-- (If running fresh from CREATE OR REPLACE TABLE above, these will produce harmless errors)



ALTER TABLE dq_demo.ecommerce.daily_transactions
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.ROW_COUNT ON ()
    ANOMALY_DETECTION = TRUE;

ALTER TABLE dq_demo.ecommerce.daily_transactions
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.FRESHNESS ON (txn_date)
    ANOMALY_DETECTION = TRUE;

-- 15d. Create a table that simulates FRESHNESS staleness
-- (A table that hasn't been updated for an unusually long time)
CREATE OR REPLACE TABLE dq_demo.ecommerce.inventory_snapshots (
    snapshot_id     INT AUTOINCREMENT,
    product_id      INT,
    warehouse       VARCHAR(30),
    quantity        INT,
    last_updated    TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Insert data with old timestamps (simulating a stale pipeline)
INSERT INTO dq_demo.ecommerce.inventory_snapshots (product_id, warehouse, quantity, last_updated)
SELECT
    UNIFORM(1, 15, RANDOM()) AS product_id,
    CASE UNIFORM(1, 3, RANDOM())
        WHEN 1 THEN 'Warehouse-East'
        WHEN 2 THEN 'Warehouse-West'
        ELSE 'Warehouse-Central'
    END AS warehouse,
    UNIFORM(0, 500, RANDOM()) AS quantity,
    -- Data is 7 days old (stale!)
    DATEADD('day', -7, CURRENT_TIMESTAMP()) AS last_updated
FROM TABLE(GENERATOR(ROWCOUNT => 200));

ALTER TABLE dq_demo.ecommerce.inventory_snapshots SET DATA_METRIC_SCHEDULE = '5 MINUTE';

-- Drop existing DMFs first to make script re-runnable



ALTER TABLE dq_demo.ecommerce.inventory_snapshots
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.FRESHNESS ON (last_updated)
    ANOMALY_DETECTION = TRUE;

ALTER TABLE dq_demo.ecommerce.inventory_snapshots
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.ROW_COUNT ON ()
    ANOMALY_DETECTION = TRUE;

-- Generate query activity on new tables
SELECT COUNT(*), SUM(amount) FROM dq_demo.ecommerce.daily_transactions WHERE txn_date = CURRENT_DATE();
SELECT region, COUNT(*) FROM dq_demo.ecommerce.daily_transactions GROUP BY region;
SELECT * FROM dq_demo.ecommerce.inventory_snapshots WHERE quantity < 50;


-- ================================================================
-- SECTION 16: MORE FAILED EXPECTATIONS SCENARIOS
-- ================================================================
-- These create additional expectation failures to populate the dashboard

-- 16a. Add more DMFs + expectations to daily_transactions
ALTER TABLE dq_demo.ecommerce.daily_transactions
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT ON (customer_id);

ALTER TABLE dq_demo.ecommerce.daily_transactions
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NEGATIVE_COUNT ON (amount);

ALTER TABLE dq_demo.ecommerce.daily_transactions
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NEGATIVE_COUNT ON (quantity);

ALTER TABLE dq_demo.ecommerce.daily_transactions
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.ACCEPTED_VALUES ON (
        payment_method, payment_method -> payment_method IN ('credit_card', 'debit_card', 'paypal', 'bank_transfer'));

-- Expectations on daily_transactions
ALTER TABLE dq_demo.ecommerce.daily_transactions
    MODIFY DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT ON (customer_id)
    ADD EXPECTATION no_null_customers (VALUE = 0);

ALTER TABLE dq_demo.ecommerce.daily_transactions
    MODIFY DATA METRIC FUNCTION SNOWFLAKE.CORE.NEGATIVE_COUNT ON (amount)
    ADD EXPECTATION no_negative_amounts (VALUE = 0);

ALTER TABLE dq_demo.ecommerce.daily_transactions
    MODIFY DATA METRIC FUNCTION SNOWFLAKE.CORE.NEGATIVE_COUNT ON (quantity)
    ADD EXPECTATION no_negative_quantities (VALUE = 0);

ALTER TABLE dq_demo.ecommerce.daily_transactions
    MODIFY DATA METRIC FUNCTION SNOWFLAKE.CORE.ROW_COUNT ON ()
    ADD EXPECTATION healthy_volume (VALUE >= 100);

-- 16b. Intentionally corrupt some data to trigger failures
-- Add rows with NULL customer_id (violates no_null_customers expectation)
INSERT INTO dq_demo.ecommerce.daily_transactions (txn_date, customer_id, product_id, quantity, amount, payment_method, region)
VALUES
    (CURRENT_DATE(), NULL, 5, 2, 50.00, 'credit_card', 'North'),
    (CURRENT_DATE(), NULL, 3, 1, 25.00, 'paypal', 'South'),
    (CURRENT_DATE(), NULL, 8, 3, 75.00, 'debit_card', 'East');

-- Add rows with negative amounts (violates no_negative_amounts expectation)
INSERT INTO dq_demo.ecommerce.daily_transactions (txn_date, customer_id, product_id, quantity, amount, payment_method, region)
VALUES
    (CURRENT_DATE(), 5, 2, 1, -99.99, 'credit_card', 'West'),
    (CURRENT_DATE(), 12, 7, 2, -45.00, 'bank_transfer', 'North');

-- Add rows with negative quantities (violates no_negative_quantities)
INSERT INTO dq_demo.ecommerce.daily_transactions (txn_date, customer_id, product_id, quantity, amount, payment_method, region)
VALUES
    (CURRENT_DATE(), 8, 4, -3, 120.00, 'debit_card', 'South');

-- 16c. Add expectations on inventory_snapshots that will FAIL
ALTER TABLE dq_demo.ecommerce.inventory_snapshots
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NULL_COUNT ON (product_id);

ALTER TABLE dq_demo.ecommerce.inventory_snapshots
    ADD DATA METRIC FUNCTION SNOWFLAKE.CORE.NEGATIVE_COUNT ON (quantity);

ALTER TABLE dq_demo.ecommerce.inventory_snapshots
    MODIFY DATA METRIC FUNCTION SNOWFLAKE.CORE.NEGATIVE_COUNT ON (quantity)
    ADD EXPECTATION no_negative_inventory (VALUE = 0);

-- Insert bad inventory data
INSERT INTO dq_demo.ecommerce.inventory_snapshots (product_id, warehouse, quantity, last_updated)
VALUES
    (3, 'Warehouse-East', -50, DATEADD('day', -7, CURRENT_TIMESTAMP())),
    (7, 'Warehouse-West', -20, DATEADD('day', -7, CURRENT_TIMESTAMP())),
    (NULL, 'Warehouse-Central', 100, DATEADD('day', -7, CURRENT_TIMESTAMP()));

-- 16d. Add more expectations on existing tables that WILL FAIL

-- Products: no blank SKUs (will fail - we have blank SKUs in data)
ALTER TABLE dq_demo.ecommerce.products
    MODIFY DATA METRIC FUNCTION SNOWFLAKE.CORE.BLANK_COUNT ON (sku)
    ADD EXPECTATION no_blank_skus (VALUE = 0);

-- Products: no duplicate SKUs (will fail - we have duplicate ELEC-001)
ALTER TABLE dq_demo.ecommerce.products
    MODIFY DATA METRIC FUNCTION SNOWFLAKE.CORE.DUPLICATE_COUNT ON (sku)
    ADD EXPECTATION no_duplicate_skus (VALUE = 0);

-- Products: no zero prices
ALTER TABLE dq_demo.ecommerce.products
    MODIFY DATA METRIC FUNCTION SNOWFLAKE.CORE.ZERO_COUNT ON (price)
    ADD EXPECTATION no_zero_prices (VALUE = 0);

-- Customers: no blank cities (will fail)
ALTER TABLE dq_demo.ecommerce.customers
    MODIFY DATA METRIC FUNCTION SNOWFLAKE.CORE.BLANK_COUNT ON (city)
    ADD EXPECTATION no_blank_cities (VALUE = 0);

-- Customers: no untrimmed city names (will fail)
ALTER TABLE dq_demo.ecommerce.customers
    MODIFY DATA METRIC FUNCTION SNOWFLAKE.CORE.UNTRIMMED_STRING_COUNT ON (city)
    ADD EXPECTATION no_untrimmed_cities (VALUE = 0);

-- Orders: all statuses must be valid (will fail - we have 'INVALID')
ALTER TABLE dq_demo.ecommerce.orders
    MODIFY DATA METRIC FUNCTION SNOWFLAKE.CORE.ACCEPTED_VALUES ON (
        status, status -> status IN ('pending', 'shipped', 'completed', 'cancelled', 'returned'))
    ADD EXPECTATION all_valid_statuses (VALUE = 0);

-- Orders: no untrimmed notes (will fail)
ALTER TABLE dq_demo.ecommerce.orders
    MODIFY DATA METRIC FUNCTION SNOWFLAKE.CORE.UNTRIMMED_STRING_COUNT ON (notes)
    ADD EXPECTATION no_untrimmed_notes (VALUE = 0);

-- Orders: discount must not be negative (will fail)
ALTER TABLE dq_demo.ecommerce.orders
    MODIFY DATA METRIC FUNCTION SNOWFLAKE.CORE.NEGATIVE_COUNT ON (discount_pct)
    ADD EXPECTATION no_negative_discounts (VALUE = 0);


-- ================================================================
-- SECTION 17: QUERY AUTOMATIC INSIGHTS
-- ================================================================

-- 17a. View automatic data quality insights (populated by Snowflake automatically)
SELECT *
FROM SNOWFLAKE.LOCAL.AUTOMATIC_DATA_QUALITY_MONITORING_RESULTS
ORDER BY measurement_time DESC
LIMIT 50;

-- 17b. Filter to just anomalies
SELECT
    measurement_time,
    table_database,
    table_schema,
    table_name,
    metric_name,
    value,
    forecast,
    lower_bound,
    upper_bound,
    is_anomaly
FROM SNOWFLAKE.LOCAL.AUTOMATIC_DATA_QUALITY_MONITORING_RESULTS
WHERE is_anomaly = TRUE
ORDER BY measurement_time DESC;

-- 17c. View ALL failed expectations across all tables
SELECT * FROM TABLE(SYSTEM$EVALUATE_DATA_QUALITY_EXPECTATIONS('DQ_DEMO.ECOMMERCE.CUSTOMERS'));
SELECT * FROM TABLE(SYSTEM$EVALUATE_DATA_QUALITY_EXPECTATIONS('DQ_DEMO.ECOMMERCE.ORDERS'));
SELECT * FROM TABLE(SYSTEM$EVALUATE_DATA_QUALITY_EXPECTATIONS('DQ_DEMO.ECOMMERCE.PRODUCTS'));
SELECT * FROM TABLE(SYSTEM$EVALUATE_DATA_QUALITY_EXPECTATIONS('DQ_DEMO.ECOMMERCE.DAILY_TRANSACTIONS'));
SELECT * FROM TABLE(SYSTEM$EVALUATE_DATA_QUALITY_EXPECTATIONS('DQ_DEMO.ECOMMERCE.INVENTORY_SNAPSHOTS'));

-- 17d. Quick preview: call DMFs directly to see which expectations will fail
SELECT 'PRODUCTS: negative prices' AS check_name,
       SNOWFLAKE.CORE.NEGATIVE_COUNT(SELECT price FROM products) AS violations;
SELECT 'PRODUCTS: zero prices' AS check_name,
       SNOWFLAKE.CORE.ZERO_COUNT(SELECT price FROM products) AS violations;
SELECT 'PRODUCTS: blank SKUs' AS check_name,
       SNOWFLAKE.CORE.BLANK_COUNT(SELECT sku FROM products) AS violations;
SELECT 'PRODUCTS: duplicate SKUs' AS check_name,
       SNOWFLAKE.CORE.DUPLICATE_COUNT(SELECT sku FROM products) AS violations;
SELECT 'CUSTOMERS: blank cities' AS check_name,
       SNOWFLAKE.CORE.BLANK_COUNT(SELECT city FROM customers) AS violations;
SELECT 'CUSTOMERS: untrimmed cities' AS check_name,
       SNOWFLAKE.CORE.UNTRIMMED_STRING_COUNT(SELECT city FROM customers) AS violations;
SELECT 'ORDERS: negative discounts' AS check_name,
       SNOWFLAKE.CORE.NEGATIVE_COUNT(SELECT discount_pct FROM orders) AS violations;
SELECT 'ORDERS: negative amounts' AS check_name,
       SNOWFLAKE.CORE.NEGATIVE_COUNT(SELECT total_amount FROM orders) AS violations;
SELECT 'DAILY_TXN: null customers' AS check_name,
       SNOWFLAKE.CORE.NULL_COUNT(SELECT customer_id FROM daily_transactions) AS violations;
SELECT 'DAILY_TXN: negative amounts' AS check_name,
       SNOWFLAKE.CORE.NEGATIVE_COUNT(SELECT amount FROM daily_transactions) AS violations;
SELECT 'INVENTORY: negative quantity' AS check_name,
       SNOWFLAKE.CORE.NEGATIVE_COUNT(SELECT quantity FROM inventory_snapshots) AS violations;


-- ================================================================
-- SECTION 18: EMAIL NOTIFICATIONS FOR DATA QUALITY ISSUES
-- ================================================================
-- Sends an email alert whenever:
--   - An expectation is violated (e.g., negative prices found)
--   - An anomaly is detected (volume or freshness deviation)
--
-- IMPORTANT: Replace 'your.email@example.com' with your actual
-- verified Snowflake email address before running.
-- ================================================================

-- 18a. Create the email notification integration
-- The email must belong to a user in your account AND be verified.
-- To verify: User menu > Preferences > Notifications > Verify email
CREATE OR REPLACE NOTIFICATION INTEGRATION dq_email_alerts
    TYPE = EMAIL
    ENABLED = TRUE
    ALLOWED_RECIPIENTS = ('vinothtrue@gmail.com');

-- 18b. Grant required privileges
-- The database owner needs MANAGE DATA QUALITY + USAGE on the integration
GRANT MANAGE DATA QUALITY ON ACCOUNT TO ROLE ACCOUNTADMIN;
GRANT USAGE ON INTEGRATION dq_email_alerts TO ROLE ACCOUNTADMIN;

-- 18c. Enable notifications on the DQ_DEMO database
-- This turns on alerts for ALL DMF associations in the database
ALTER DATABASE dq_demo SET DATA_QUALITY_MONITORING_SETTINGS =
$$
notification:
  enabled: TRUE
  integrations:
    - DQ_EMAIL_ALERTS
  cooldown_hours: 120
  metadata_included: TRUE
$$;

-- cooldown_hours: minimum gap between notifications (prevents email flooding)
-- metadata_included: includes table name, column, and DMF name in the email

-- 18d. (Optional) Send to multiple recipients and/or add direct emails
-- You can combine integrations with direct email recipients:

ALTER DATABASE dq_demo SET DATA_QUALITY_MONITORING_SETTINGS =
$$
notification:
  enabled: true
  email_recipients: ['vinothtrue@gmail.com']
  integrations:
    - DQ_EMAIL_ALERTS
  cooldown_hours: 2
  metadata_included: TRUE
$$;


-- 18e. (Optional) Disable notification for a specific DMF association
-- Use this if a known issue generates too much noise
/*
ALTER TABLE orders
    MODIFY DATA METRIC FUNCTION SNOWFLAKE.CORE.NEGATIVE_COUNT ON (total_amount)
    SET DATA_QUALITY_NOTIFICATION = FALSE;
*/

-- 18f. (Optional) Webhook notification to Slack
-- Sends DQ alerts to a Slack channel via incoming webhook
/*
CREATE OR REPLACE SECRET dq_demo.ecommerce.slack_webhook_secret
    TYPE = GENERIC_STRING
    SECRET_STRING = 'T00000000/B00000000/your-slack-webhook-token';

CREATE OR REPLACE NOTIFICATION INTEGRATION dq_slack_alerts
    TYPE = WEBHOOK
    ENABLED = TRUE
    WEBHOOK_URL = 'https://hooks.slack.com/services/SNOWFLAKE_WEBHOOK_SECRET'
    WEBHOOK_SECRET = dq_demo.ecommerce.slack_webhook_secret
    WEBHOOK_BODY_TEMPLATE = '{"text": "SNOWFLAKE_WEBHOOK_MESSAGE"}'
    WEBHOOK_HEADERS = ('Content-Type'='application/json');

GRANT USAGE ON INTEGRATION dq_slack_alerts TO ROLE ACCOUNTADMIN;

-- Then add to database settings:
ALTER DATABASE dq_demo SET DATA_QUALITY_MONITORING_SETTINGS =
$$
notification:
  enabled: TRUE
  integrations:
    - DQ_EMAIL_ALERTS
    - DQ_SLACK_ALERTS
  cooldown_hours: 1
  metadata_included: TRUE
$$;
*/

-- 18g. Verify notification status for your DMF associations
SELECT
*
FROM TABLE(
    INFORMATION_SCHEMA.DATA_METRIC_FUNCTION_REFERENCES(
        REF_ENTITY_NAME => 'dq_demo.ecommerce.orders',
        REF_ENTITY_DOMAIN => 'TABLE'
    )
);

SELECT
*
FROM TABLE(
    INFORMATION_SCHEMA.DATA_METRIC_FUNCTION_REFERENCES(
        REF_ENTITY_NAME => 'dq_demo.ecommerce.customers',
        REF_ENTITY_DOMAIN => 'TABLE'
    )
);

SELECT
*
FROM TABLE(
    INFORMATION_SCHEMA.DATA_METRIC_FUNCTION_REFERENCES(
        REF_ENTITY_NAME => 'dq_demo.ecommerce.products',
        REF_ENTITY_DOMAIN => 'TABLE'
    )
);