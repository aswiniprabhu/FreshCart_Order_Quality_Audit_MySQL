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
