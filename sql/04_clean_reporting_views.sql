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
