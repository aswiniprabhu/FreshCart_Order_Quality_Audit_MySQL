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
