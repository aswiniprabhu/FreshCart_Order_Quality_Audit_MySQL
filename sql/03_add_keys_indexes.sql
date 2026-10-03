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
