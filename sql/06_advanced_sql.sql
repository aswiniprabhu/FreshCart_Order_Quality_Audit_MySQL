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
