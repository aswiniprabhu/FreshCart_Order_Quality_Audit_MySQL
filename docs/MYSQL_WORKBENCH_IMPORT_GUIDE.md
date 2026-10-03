# MySQL Workbench Import Guide

Use this guide to run the project on your existing **Local instance MySQL80** connection.

## 1. Connect to MySQL

Open MySQL Workbench and double-click **Local instance MySQL80** (or your existing local connection).

`localhost:3306` means Workbench is connecting to the MySQL server running on your own computer through MySQL's usual port 3306.

## 2. Create the FreshCart database and tables

1. Choose **File → Open SQL Script**.
2. Open `sql/01_create_tables.sql`.
3. Click the lightning-bolt **Execute** button.
4. In the left **SCHEMAS** panel, click refresh.
5. You should now see a database/schema named `freshcart`.
6. Expand `freshcart → Tables` and confirm that the eight raw tables exist.

## 3. Import each CSV into its existing table

Use the sample CSV files in `data/sample/` first.

For each CSV:

1. In the **SCHEMAS** panel, right-click the `freshcart` schema.
2. Choose **Table Data Import Wizard**.
3. Browse to the CSV file.
4. Choose **Use existing table** and select the matching table shown below.
5. Confirm the column mapping.
6. Complete the import.

| CSV file | Existing table |
|---|---|
| `olist_customers_dataset.csv` | `customers` |
| `olist_orders_dataset.csv` | `orders` |
| `olist_order_items_dataset.csv` | `order_items` |
| `olist_order_payments_dataset.csv` | `order_payments` |
| `olist_order_reviews_dataset.csv` | `order_reviews` |
| `olist_products_dataset.csv` | `products` |
| `olist_sellers_dataset.csv` | `sellers` |
| `product_category_name_translation.csv` | `category_translation` |

If the wizard does not show **Use existing table** in your Workbench version, open the target table's context menu and use its data-import option, or tell me what screen you see and I can guide you from there.

## 4. Confirm the import

Run:

```sql
USE freshcart;
SELECT COUNT(*) FROM orders;
SELECT COUNT(*) FROM customers;
SELECT COUNT(*) FROM order_items;
```

The counts should be greater than zero.

## 5. Run the project in order

Run these scripts one at a time:

`02_data_quality_checks.sql` → review issues → `03_add_keys_indexes.sql` → `04_clean_reporting_views.sql` → `05_business_analysis.sql` → `06_advanced_sql.sql` → `07_kpi_reporting.sql` → `08_batch_quality_scorecard.sql`.

Do **not** add keys until duplicate and orphan-record checks are acceptable.

## 6. Important MySQL note

This project requires **MySQL 8.0+** because it uses CTEs and window functions such as `LAG`, `RANK`, `ROW_NUMBER` and `NTILE`.
