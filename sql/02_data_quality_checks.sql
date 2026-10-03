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
