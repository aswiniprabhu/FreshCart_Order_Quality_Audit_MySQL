# Data Dictionary

| Table | Key columns | Purpose |
|---|---|---|
| `customers` | `customer_id`, `customer_unique_id` | Order-level customer ID plus repeat-customer identifier and location |
| `orders` | `order_id`, `customer_id` | Order status and purchase/approval/shipping/delivery timestamps |
| `order_items` | `order_id`, `order_item_id`, `product_id`, `seller_id` | Line items, item price, freight and seller fulfilment |
| `order_payments` | `order_id`, `payment_sequential` | Payment method, installments and payment value |
| `order_reviews` | `review_id`, `order_id` | Customer review scores and review timestamps |
| `products` | `product_id`, `product_category_name` | Product category and physical/product-description attributes |
| `sellers` | `seller_id` | Seller location |
| `category_translation` | `product_category_name` | Portuguese-to-English category mapping |

## Important identifiers

- `customer_id`: order-level customer record. In the Olist model, a repeat shopper may have different `customer_id` values across orders.
- `customer_unique_id`: use this field to identify repeat shoppers.
- `order_id`: main transaction key connecting orders, items, payments and reviews.
- `order_item_id`: line-number within an order.

## Important measures

- **Item revenue:** `SUM(order_items.price)`.
- **Freight value:** `SUM(order_items.freight_value)`.
- **Gross order value:** item price + freight at order level.
- **Payment value:** amount in `order_payments`; aggregate by order before joining to items.
- **Late delivery:** delivered customer timestamp later than estimated delivery timestamp.
- **Failed order:** project label for `canceled` or `unavailable`; this is a reporting grouping, not a claim of financial loss.
