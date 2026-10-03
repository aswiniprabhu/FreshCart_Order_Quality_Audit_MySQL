-- ============================================================================
-- 01_create_tables.sql
-- ============================================================================

-- FreshCart Order Quality Audit
-- MySQL 8.0+
-- Step 1: Create lightly constrained staging-style tables for CSV import.

CREATE DATABASE IF NOT EXISTS freshcart
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci;

USE freshcart;

-- This makes the setup script safe to rerun even after foreign keys were added.
SET FOREIGN_KEY_CHECKS = 0;

DROP VIEW IF EXISTS vw_kpi_summary;
DROP VIEW IF EXISTS vw_repeat_customer_kpis;
DROP VIEW IF EXISTS vw_customer_order_counts;
DROP VIEW IF EXISTS vw_category_order_detail;
DROP VIEW IF EXISTS vw_order_master;
DROP VIEW IF EXISTS vw_review_summary;
DROP VIEW IF EXISTS vw_payment_summary;
DROP VIEW IF EXISTS vw_item_summary;

DROP TABLE IF EXISTS category_translation;
DROP TABLE IF EXISTS order_reviews;
DROP TABLE IF EXISTS order_payments;
DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS sellers;
DROP TABLE IF EXISTS customers;

SET FOREIGN_KEY_CHECKS = 1;

CREATE TABLE customers (
    customer_id CHAR(32),
    customer_unique_id CHAR(32),
    customer_zip_code_prefix INT,
    customer_city VARCHAR(100),
    customer_state CHAR(2)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE orders (
    order_id CHAR(32),
    customer_id CHAR(32),
    order_status VARCHAR(30),
    order_purchase_timestamp DATETIME,
    order_approved_at DATETIME,
    order_delivered_carrier_date DATETIME,
    order_delivered_customer_date DATETIME,
    order_estimated_delivery_date DATETIME
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE order_items (
    order_id CHAR(32),
    order_item_id INT,
    product_id CHAR(32),
    seller_id CHAR(32),
    shipping_limit_date DATETIME,
    price DECIMAL(12,2),
    freight_value DECIMAL(12,2)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE order_payments (
    order_id CHAR(32),
    payment_sequential INT,
    payment_type VARCHAR(30),
    payment_installments INT,
    payment_value DECIMAL(12,2)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE order_reviews (
    review_id CHAR(32),
    order_id CHAR(32),
    review_score INT,
    review_comment_title TEXT,
    review_comment_message TEXT,
    review_creation_date DATETIME,
    review_answer_timestamp DATETIME
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE products (
    product_id CHAR(32),
    product_category_name VARCHAR(100),
    product_name_lenght INT,
    product_description_lenght INT,
    product_photos_qty INT,
    product_weight_g INT,
    product_length_cm INT,
    product_height_cm INT,
    product_width_cm INT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE sellers (
    seller_id CHAR(32),
    seller_zip_code_prefix INT,
    seller_city VARCHAR(100),
    seller_state CHAR(2)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE category_translation (
    product_category_name VARCHAR(100),
    product_category_name_english VARCHAR(100)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Import the CSVs next, then run 02_data_quality_checks.sql BEFORE adding keys.

-- ============================================================================
-- 02_data_quality_checks.sql
-- ============================================================================

-- Step 2: Data quality checks BEFORE adding constraints.
USE freshcart;

-- A. Row counts
SELECT 'customers' AS table_name, COUNT(*) AS row_count FROM customers
UNION ALL SELECT 'orders', COUNT(*) FROM orders
UNION ALL SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL SELECT 'order_payments', COUNT(*) FROM order_payments
UNION ALL SELECT 'order_reviews', COUNT(*) FROM order_reviews
UNION ALL SELECT 'products', COUNT(*) FROM products
UNION ALL SELECT 'sellers', COUNT(*) FROM sellers
UNION ALL SELECT 'category_translation', COUNT(*) FROM category_translation
ORDER BY table_name;

-- B. Duplicate business keys
SELECT 'customers.customer_id' AS check_name, COUNT(*) AS duplicate_groups
FROM (SELECT customer_id FROM customers GROUP BY customer_id HAVING COUNT(*) > 1) x
UNION ALL
SELECT 'orders.order_id', COUNT(*)
FROM (SELECT order_id FROM orders GROUP BY order_id HAVING COUNT(*) > 1) x
UNION ALL
SELECT 'products.product_id', COUNT(*)
FROM (SELECT product_id FROM products GROUP BY product_id HAVING COUNT(*) > 1) x
UNION ALL
SELECT 'sellers.seller_id', COUNT(*)
FROM (SELECT seller_id FROM sellers GROUP BY seller_id HAVING COUNT(*) > 1) x
UNION ALL
SELECT 'order_items(order_id, order_item_id)', COUNT(*)
FROM (SELECT order_id, order_item_id FROM order_items GROUP BY order_id, order_item_id HAVING COUNT(*) > 1) x
UNION ALL
SELECT 'order_payments(order_id, payment_sequential)', COUNT(*)
FROM (SELECT order_id, payment_sequential FROM order_payments GROUP BY order_id, payment_sequential HAVING COUNT(*) > 1) x
UNION ALL
SELECT 'order_reviews(review_id, order_id)', COUNT(*)
FROM (SELECT review_id, order_id FROM order_reviews GROUP BY review_id, order_id HAVING COUNT(*) > 1) x;

-- C. NULL / blank critical keys
SELECT 'orders missing order_id' AS check_name, COUNT(*) AS issue_count FROM orders WHERE NULLIF(TRIM(order_id),'') IS NULL
UNION ALL SELECT 'orders missing customer_id', COUNT(*) FROM orders WHERE NULLIF(TRIM(customer_id),'') IS NULL
UNION ALL SELECT 'items missing product_id', COUNT(*) FROM order_items WHERE NULLIF(TRIM(product_id),'') IS NULL
UNION ALL SELECT 'items missing seller_id', COUNT(*) FROM order_items WHERE NULLIF(TRIM(seller_id),'') IS NULL
UNION ALL SELECT 'payments missing order_id', COUNT(*) FROM order_payments WHERE NULLIF(TRIM(order_id),'') IS NULL;

-- D. Orphan records
SELECT 'orders without customer' AS check_name, COUNT(*) AS issue_count
FROM orders o LEFT JOIN customers c ON c.customer_id=o.customer_id WHERE c.customer_id IS NULL
UNION ALL
SELECT 'items without order', COUNT(*) FROM order_items i LEFT JOIN orders o ON o.order_id=i.order_id WHERE o.order_id IS NULL
UNION ALL
SELECT 'items without product', COUNT(*) FROM order_items i LEFT JOIN products p ON p.product_id=i.product_id WHERE p.product_id IS NULL
UNION ALL
SELECT 'items without seller', COUNT(*) FROM order_items i LEFT JOIN sellers s ON s.seller_id=i.seller_id WHERE s.seller_id IS NULL
UNION ALL
SELECT 'payments without order', COUNT(*) FROM order_payments p LEFT JOIN orders o ON o.order_id=p.order_id WHERE o.order_id IS NULL
UNION ALL
SELECT 'reviews without order', COUNT(*) FROM order_reviews r LEFT JOIN orders o ON o.order_id=r.order_id WHERE o.order_id IS NULL;

-- E. Invalid values
SELECT 'negative item price' AS check_name, COUNT(*) AS issue_count FROM order_items WHERE price < 0
UNION ALL SELECT 'negative freight', COUNT(*) FROM order_items WHERE freight_value < 0
UNION ALL SELECT 'negative payment', COUNT(*) FROM order_payments WHERE payment_value < 0
UNION ALL SELECT 'invalid review score', COUNT(*) FROM order_reviews WHERE review_score NOT BETWEEN 1 AND 5;

-- F. Timestamp / status consistency
SELECT 'approved before purchase' AS check_name, COUNT(*) AS issue_count
FROM orders WHERE order_approved_at < order_purchase_timestamp
UNION ALL
SELECT 'carrier date before purchase', COUNT(*)
FROM orders WHERE order_delivered_carrier_date < order_purchase_timestamp
UNION ALL
SELECT 'customer delivery before carrier', COUNT(*)
FROM orders WHERE order_delivered_customer_date < order_delivered_carrier_date
UNION ALL
SELECT 'delivered status missing customer delivery date', COUNT(*)
FROM orders WHERE order_status='delivered' AND order_delivered_customer_date IS NULL;

-- G. Product-category completeness
SELECT 'products with missing category' AS check_name, COUNT(*) AS issue_count
FROM products WHERE NULLIF(TRIM(product_category_name),'') IS NULL
UNION ALL
SELECT 'categories missing English mapping', COUNT(*)
FROM products p
LEFT JOIN category_translation t ON t.product_category_name = p.product_category_name
WHERE NULLIF(TRIM(p.product_category_name),'') IS NOT NULL
  AND t.product_category_name IS NULL;

-- H. Reconciliation review: order item+freight total vs total payment value
WITH item_totals AS (
    SELECT order_id, SUM(price + freight_value) AS item_plus_freight
    FROM order_items GROUP BY order_id
), pay_totals AS (
    SELECT order_id, SUM(payment_value) AS payment_total
    FROM order_payments GROUP BY order_id
)
SELECT o.order_id,
       ROUND(COALESCE(i.item_plus_freight,0),2) AS item_plus_freight,
       ROUND(COALESCE(p.payment_total,0),2) AS payment_total,
       ROUND(COALESCE(p.payment_total,0)-COALESCE(i.item_plus_freight,0),2) AS difference
FROM orders o
LEFT JOIN item_totals i ON i.order_id = o.order_id
LEFT JOIN pay_totals p ON p.order_id = o.order_id
WHERE ABS(COALESCE(p.payment_total,0)-COALESCE(i.item_plus_freight,0)) > 1.00
ORDER BY ABS(COALESCE(p.payment_total,0)-COALESCE(i.item_plus_freight,0)) DESC;

-- ============================================================================
-- 03_add_keys_indexes.sql
-- ============================================================================

-- Step 3: Run only after duplicate/orphan checks are acceptable.
USE freshcart;

ALTER TABLE customers ADD CONSTRAINT pk_customers PRIMARY KEY (customer_id);
ALTER TABLE orders ADD CONSTRAINT pk_orders PRIMARY KEY (order_id);
ALTER TABLE products ADD CONSTRAINT pk_products PRIMARY KEY (product_id);
ALTER TABLE sellers ADD CONSTRAINT pk_sellers PRIMARY KEY (seller_id);
ALTER TABLE category_translation ADD CONSTRAINT pk_category_translation PRIMARY KEY (product_category_name);
ALTER TABLE order_items ADD CONSTRAINT pk_order_items PRIMARY KEY (order_id, order_item_id);
ALTER TABLE order_payments ADD CONSTRAINT pk_order_payments PRIMARY KEY (order_id, payment_sequential);

-- Reviews are not forced unique at raw level; duplicate review records remain a data-quality finding.
CREATE INDEX idx_reviews_review_id ON order_reviews(review_id);

ALTER TABLE orders ADD CONSTRAINT fk_orders_customer FOREIGN KEY (customer_id) REFERENCES customers(customer_id);
ALTER TABLE order_items ADD CONSTRAINT fk_items_order FOREIGN KEY (order_id) REFERENCES orders(order_id);
ALTER TABLE order_items ADD CONSTRAINT fk_items_product FOREIGN KEY (product_id) REFERENCES products(product_id);
ALTER TABLE order_items ADD CONSTRAINT fk_items_seller FOREIGN KEY (seller_id) REFERENCES sellers(seller_id);
ALTER TABLE order_payments ADD CONSTRAINT fk_payments_order FOREIGN KEY (order_id) REFERENCES orders(order_id);
ALTER TABLE order_reviews ADD CONSTRAINT fk_reviews_order FOREIGN KEY (order_id) REFERENCES orders(order_id);

CREATE INDEX idx_customers_unique_id ON customers(customer_unique_id);
CREATE INDEX idx_orders_customer_id ON orders(customer_id);
CREATE INDEX idx_orders_status ON orders(order_status);
CREATE INDEX idx_orders_purchase_ts ON orders(order_purchase_timestamp);
CREATE INDEX idx_items_product ON order_items(product_id);
CREATE INDEX idx_items_seller ON order_items(seller_id);
CREATE INDEX idx_payments_type ON order_payments(payment_type);
CREATE INDEX idx_products_category ON products(product_category_name);

-- ============================================================================
-- 04_clean_reporting_views.sql
-- ============================================================================

-- Step 4: Reusable clean reporting views.
USE freshcart;

-- Aggregate one-to-many tables BEFORE joining to prevent fan-out.
CREATE OR REPLACE VIEW vw_item_summary AS
SELECT order_id,
       COUNT(*) AS item_count,
       COUNT(DISTINCT product_id) AS distinct_products,
       COUNT(DISTINCT seller_id) AS seller_count,
       ROUND(SUM(price),2) AS item_revenue,
       ROUND(SUM(freight_value),2) AS freight_value,
       ROUND(SUM(price + freight_value),2) AS gross_order_value
FROM order_items
GROUP BY order_id;

CREATE OR REPLACE VIEW vw_payment_summary AS
SELECT order_id,
       COUNT(*) AS payment_records,
       GROUP_CONCAT(DISTINCT payment_type ORDER BY payment_type SEPARATOR ', ') AS payment_methods,
       MAX(payment_installments) AS max_installments,
       ROUND(SUM(payment_value),2) AS payment_value
FROM order_payments
GROUP BY order_id;

CREATE OR REPLACE VIEW vw_review_summary AS
SELECT order_id,
       COUNT(*) AS review_count,
       ROUND(AVG(review_score),2) AS avg_review_score
FROM order_reviews
GROUP BY order_id;

CREATE OR REPLACE VIEW vw_order_master AS
SELECT
    o.order_id,
    c.customer_id,
    c.customer_unique_id,
    c.customer_city,
    c.customer_state,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_approved_at,
    o.order_delivered_carrier_date,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,
    i.item_count,
    i.distinct_products,
    i.seller_count,
    i.item_revenue,
    i.freight_value,
    i.gross_order_value,
    p.payment_records,
    p.payment_methods,
    p.max_installments,
    p.payment_value,
    r.avg_review_score,
    CASE
        WHEN o.order_delivered_customer_date IS NOT NULL
        THEN DATEDIFF(o.order_delivered_customer_date, o.order_purchase_timestamp)
    END AS delivery_days,
    CASE
        WHEN o.order_status='delivered'
         AND o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 1
        WHEN o.order_status='delivered' THEN 0
    END AS late_delivery_flag,
    CASE WHEN o.order_status IN ('canceled','unavailable') THEN 1 ELSE 0 END AS failed_order_flag
FROM orders o
LEFT JOIN customers c ON c.customer_id=o.customer_id
LEFT JOIN vw_item_summary i ON i.order_id=o.order_id
LEFT JOIN vw_payment_summary p ON p.order_id=o.order_id
LEFT JOIN vw_review_summary r ON r.order_id=o.order_id;

CREATE OR REPLACE VIEW vw_category_order_detail AS
SELECT
    i.order_id,
    i.order_item_id,
    i.product_id,
    i.seller_id,
    COALESCE(t.product_category_name_english, p.product_category_name, 'unknown') AS category,
    i.price,
    i.freight_value,
    i.price + i.freight_value AS item_plus_freight,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,
    c.customer_unique_id,
    c.customer_state,
    s.seller_state,
    CASE WHEN o.order_status='delivered' AND o.order_delivered_customer_date > o.order_estimated_delivery_date THEN 1 ELSE 0 END AS late_delivery_flag
FROM order_items i
JOIN orders o ON o.order_id=i.order_id
JOIN customers c ON c.customer_id=o.customer_id
JOIN products p ON p.product_id=i.product_id
JOIN sellers s ON s.seller_id=i.seller_id
LEFT JOIN category_translation t ON t.product_category_name=p.product_category_name;

-- ============================================================================
-- 05_business_analysis.sql
-- ============================================================================

-- Step 5: Business analysis queries
USE freshcart;

-- Q1. Cancellation / unavailability rate by customer state
SELECT customer_state,
       COUNT(*) AS total_orders,
       SUM(failed_order_flag) AS failed_orders,
       ROUND(100.0 * SUM(failed_order_flag) / NULLIF(COUNT(*),0),2) AS failed_order_rate_pct
FROM vw_order_master
GROUP BY customer_state
HAVING COUNT(*) >= 20
ORDER BY failed_order_rate_pct DESC, total_orders DESC;

-- Q2. Payment methods used on cancelled/unavailable orders
SELECT p.payment_type,
       COUNT(DISTINCT p.order_id) AS failed_orders,
       ROUND(SUM(p.payment_value),2) AS associated_payment_value
FROM order_payments p
JOIN orders o ON o.order_id=p.order_id
WHERE o.order_status IN ('canceled','unavailable')
GROUP BY p.payment_type
ORDER BY associated_payment_value DESC;

-- Q3. Repeat customers
WITH customer_orders AS (
    SELECT customer_unique_id, COUNT(*) AS orders_count
    FROM vw_order_master
    GROUP BY customer_unique_id
)
SELECT
    COUNT(*) AS unique_customers,
    SUM(CASE WHEN orders_count > 1 THEN 1 ELSE 0 END) AS repeat_customers,
    ROUND(100.0 * SUM(CASE WHEN orders_count > 1 THEN 1 ELSE 0 END) / NULLIF(COUNT(*),0),2) AS repeat_customer_rate_pct
FROM customer_orders;

-- Q4. Average delivery time and late-delivery rate by state
SELECT customer_state,
       SUM(CASE WHEN order_status='delivered' THEN 1 ELSE 0 END) AS delivered_orders,
       ROUND(AVG(CASE WHEN order_status='delivered' THEN delivery_days END),2) AS avg_delivery_days,
       ROUND(100.0 * AVG(CASE WHEN order_status='delivered' THEN late_delivery_flag END),2) AS late_delivery_rate_pct
FROM vw_order_master
GROUP BY customer_state
HAVING SUM(CASE WHEN order_status='delivered' THEN 1 ELSE 0 END) >= 20
ORDER BY late_delivery_rate_pct DESC;

-- Q5. Categories purchased most often by repeat customers
WITH repeats AS (
    SELECT customer_unique_id
    FROM vw_order_master
    GROUP BY customer_unique_id
    HAVING COUNT(*) > 1
)
SELECT d.category,
       COUNT(DISTINCT d.order_id) AS repeat_customer_orders,
       ROUND(SUM(d.price),2) AS item_revenue
FROM vw_category_order_detail d
JOIN repeats r ON r.customer_unique_id = d.customer_unique_id
WHERE d.order_status='delivered'
GROUP BY d.category
ORDER BY repeat_customer_orders DESC, item_revenue DESC
LIMIT 15;

-- Q6. Sellers with highest late-delivery rates (minimum 20 delivered orders)
-- Aggregate to one row per seller/order first so multi-item orders do not overweight the rate.
WITH seller_orders AS (
    SELECT seller_id, order_id,
           MAX(late_delivery_flag) AS late_delivery_flag,
           SUM(price) AS item_revenue
    FROM vw_category_order_detail
    WHERE order_status='delivered'
    GROUP BY seller_id, order_id
)
SELECT seller_id,
       COUNT(*) AS delivered_orders,
       ROUND(100.0 * AVG(late_delivery_flag),2) AS late_delivery_rate_pct,
       ROUND(SUM(item_revenue),2) AS item_revenue
FROM seller_orders
GROUP BY seller_id
HAVING COUNT(*) >= 20
ORDER BY late_delivery_rate_pct DESC, delivered_orders DESC
LIMIT 20;

-- Q7. Payment value associated with cancelled/unavailable orders
SELECT order_status,
       COUNT(*) AS orders,
       ROUND(SUM(COALESCE(payment_value,0)),2) AS associated_payment_value
FROM vw_order_master
WHERE order_status IN ('canceled','unavailable')
GROUP BY order_status
ORDER BY associated_payment_value DESC;

-- Q8. Top product categories by item revenue
SELECT category,
       COUNT(DISTINCT order_id) AS orders,
       ROUND(SUM(price),2) AS item_revenue,
       ROUND(AVG(price),2) AS avg_item_price
FROM vw_category_order_detail
WHERE order_status='delivered'
GROUP BY category
ORDER BY item_revenue DESC
LIMIT 15;

-- Q9. Relationship between delivery timeliness and customer review score
SELECT
    CASE WHEN late_delivery_flag=1 THEN 'Late' ELSE 'On time' END AS delivery_status,
    COUNT(*) AS orders_with_review,
    ROUND(AVG(avg_review_score),2) AS avg_review_score
FROM vw_order_master
WHERE order_status='delivered' AND avg_review_score IS NOT NULL
GROUP BY CASE WHEN late_delivery_flag=1 THEN 'Late' ELSE 'On time' END;

-- Q10. Monthly payment value
SELECT CAST(DATE_FORMAT(order_purchase_timestamp, '%Y-%m-01') AS DATE) AS month,
       COUNT(*) AS orders,
       ROUND(SUM(COALESCE(payment_value,0)),2) AS payment_value
FROM vw_order_master
GROUP BY month
ORDER BY month;

-- ============================================================================
-- 06_advanced_sql.sql
-- ============================================================================

-- Step 6: Advanced SQL examples: CTEs + window functions.
USE freshcart;

-- A. Month-over-month payment-value growth using LAG
WITH monthly AS (
    SELECT CAST(DATE_FORMAT(order_purchase_timestamp, '%Y-%m-01') AS DATE) AS month,
           SUM(COALESCE(payment_value,0)) AS payment_value
    FROM vw_order_master
    GROUP BY month
), with_previous AS (
    SELECT month, payment_value,
           LAG(payment_value) OVER (ORDER BY month) AS previous_month_value
    FROM monthly
)
SELECT month,
       ROUND(payment_value,2) AS payment_value,
       ROUND(previous_month_value,2) AS previous_month_value,
       ROUND(100.0 * (payment_value-previous_month_value) / NULLIF(previous_month_value,0),2) AS mom_growth_pct
FROM with_previous
ORDER BY month;

-- B. Highest-value customers ranked within each state
WITH customer_value AS (
    SELECT customer_state, customer_unique_id,
           COUNT(*) AS orders,
           SUM(COALESCE(payment_value,0)) AS payment_value
    FROM vw_order_master
    GROUP BY customer_state, customer_unique_id
), ranked AS (
    SELECT customer_state, customer_unique_id, orders, payment_value,
           RANK() OVER (PARTITION BY customer_state ORDER BY payment_value DESC) AS state_rank
    FROM customer_value
)
SELECT customer_state, customer_unique_id, orders, ROUND(payment_value,2) AS payment_value, state_rank
FROM ranked
WHERE state_rank <= 5
ORDER BY customer_state, state_rank;

-- C. Top 3 categories by item revenue in each customer state
WITH category_state AS (
    SELECT customer_state, category, SUM(price) AS item_revenue
    FROM vw_category_order_detail
    WHERE order_status='delivered'
    GROUP BY customer_state, category
), ranked AS (
    SELECT customer_state, category, item_revenue,
           ROW_NUMBER() OVER (PARTITION BY customer_state ORDER BY item_revenue DESC) AS rn
    FROM category_state
)
SELECT customer_state, category, ROUND(item_revenue,2) AS item_revenue, rn AS rank_in_state
FROM ranked
WHERE rn <= 3
ORDER BY customer_state, rn;

-- D. Customer value segments using NTILE
WITH customer_value AS (
    SELECT customer_unique_id,
           COUNT(*) AS order_count,
           SUM(COALESCE(payment_value,0)) AS lifetime_payment_value
    FROM vw_order_master
    GROUP BY customer_unique_id
), scored AS (
    SELECT customer_unique_id, order_count, lifetime_payment_value,
           NTILE(4) OVER (ORDER BY lifetime_payment_value) AS value_quartile
    FROM customer_value
)
SELECT value_quartile,
       COUNT(*) AS customers,
       ROUND(AVG(order_count),2) AS avg_orders,
       ROUND(AVG(lifetime_payment_value),2) AS avg_customer_value
FROM scored
GROUP BY value_quartile
ORDER BY value_quartile DESC;

-- ============================================================================
-- 07_kpi_reporting.sql
-- ============================================================================

-- Step 7: One-row KPI reporting view.
USE freshcart;

-- Supporting views keep the final KPI view simple and MySQL-compatible.
CREATE OR REPLACE VIEW vw_customer_order_counts AS
SELECT customer_unique_id, COUNT(*) AS order_count
FROM vw_order_master
GROUP BY customer_unique_id;

CREATE OR REPLACE VIEW vw_repeat_customer_kpis AS
SELECT
    COUNT(*) AS unique_customers,
    SUM(CASE WHEN order_count > 1 THEN 1 ELSE 0 END) AS repeat_customers,
    ROUND(100.0 * SUM(CASE WHEN order_count > 1 THEN 1 ELSE 0 END) / NULLIF(COUNT(*),0),2) AS repeat_customer_rate_pct
FROM vw_customer_order_counts;

CREATE OR REPLACE VIEW vw_kpi_summary AS
SELECT
    COUNT(*) AS total_orders,
    SUM(CASE WHEN order_status='delivered' THEN 1 ELSE 0 END) AS delivered_orders,
    ROUND(100.0 * SUM(CASE WHEN order_status='delivered' THEN 1 ELSE 0 END) / NULLIF(COUNT(*),0),2) AS delivered_rate_pct,
    SUM(CASE WHEN order_status IN ('canceled','unavailable') THEN 1 ELSE 0 END) AS failed_orders,
    ROUND(100.0 * SUM(CASE WHEN order_status IN ('canceled','unavailable') THEN 1 ELSE 0 END) / NULLIF(COUNT(*),0),2) AS failed_order_rate_pct,
    ROUND(100.0 * AVG(CASE WHEN order_status='delivered' THEN late_delivery_flag END),2) AS late_delivery_rate_pct,
    ROUND(AVG(CASE WHEN order_status='delivered' THEN delivery_days END),2) AS avg_delivery_days,
    ROUND(AVG(payment_value),2) AS avg_order_payment,
    ROUND(SUM(COALESCE(payment_value,0)),2) AS total_payment_value,
    ROUND(SUM(CASE WHEN order_status IN ('canceled','unavailable') THEN COALESCE(payment_value,0) ELSE 0 END),2) AS failed_order_payment_value,
    ROUND(AVG(avg_review_score),2) AS avg_review_score,
    MAX(r.repeat_customers) AS repeat_customers,
    MAX(r.repeat_customer_rate_pct) AS repeat_customer_rate_pct
FROM vw_order_master
CROSS JOIN vw_repeat_customer_kpis r;

SELECT * FROM vw_kpi_summary;

-- ============================================================================
-- 08_batch_quality_scorecard.sql
-- ============================================================================

-- Step 8: Batch-quality scorecard aligned to data-operations / fulfilment work.
USE freshcart;

WITH checks AS (
    SELECT 'Duplicate orders' AS check_name,
           (SELECT COUNT(*) FROM (SELECT order_id FROM orders GROUP BY order_id HAVING COUNT(*)>1) x) AS issue_count
    UNION ALL SELECT 'Orders without customer',
           (SELECT COUNT(*) FROM orders o LEFT JOIN customers c ON c.customer_id=o.customer_id WHERE c.customer_id IS NULL)
    UNION ALL SELECT 'Order items without order',
           (SELECT COUNT(*) FROM order_items i LEFT JOIN orders o ON o.order_id=i.order_id WHERE o.order_id IS NULL)
    UNION ALL SELECT 'Payments without order',
           (SELECT COUNT(*) FROM order_payments p LEFT JOIN orders o ON o.order_id=p.order_id WHERE o.order_id IS NULL)
    UNION ALL SELECT 'Negative price/freight/payment values',
           (SELECT COUNT(*) FROM order_items WHERE price<0 OR freight_value<0)
           + (SELECT COUNT(*) FROM order_payments WHERE payment_value<0)
    UNION ALL SELECT 'Invalid order chronology',
           (SELECT COUNT(*) FROM orders
            WHERE order_approved_at < order_purchase_timestamp
               OR order_delivered_carrier_date < order_purchase_timestamp
               OR order_delivered_customer_date < order_delivered_carrier_date)
    UNION ALL SELECT 'Delivered orders missing delivery date',
           (SELECT COUNT(*) FROM orders WHERE order_status='delivered' AND order_delivered_customer_date IS NULL)
    UNION ALL SELECT 'Products missing category',
           (SELECT COUNT(*) FROM products WHERE NULLIF(TRIM(product_category_name),'') IS NULL)
    UNION ALL SELECT 'Unmapped product categories',
           (SELECT COUNT(*) FROM products p
            LEFT JOIN category_translation t ON t.product_category_name = p.product_category_name
            WHERE NULLIF(TRIM(p.product_category_name),'') IS NOT NULL AND t.product_category_name IS NULL)
)
SELECT check_name,
       issue_count,
       CASE WHEN issue_count=0 THEN 'PASS' ELSE 'REVIEW' END AS status
FROM checks
ORDER BY CASE WHEN issue_count=0 THEN 1 ELSE 0 END, issue_count DESC, check_name;
