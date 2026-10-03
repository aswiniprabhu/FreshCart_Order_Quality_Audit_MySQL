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
