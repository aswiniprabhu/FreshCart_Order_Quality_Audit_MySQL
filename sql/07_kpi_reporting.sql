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
