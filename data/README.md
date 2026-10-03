# Data

## Portfolio dataset
Download the original **Brazilian E-Commerce Public Dataset by Olist** from:

- https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce
- https://github.com/olist/work-at-olist-data

Keep the original CSV filenames so they map directly to the SQL tables.

## Included demo dataset
`sample/` contains a deterministic synthetic dataset with the same core table/column structure. It is included only so the SQL project can be tested without a large download.

The demo deliberately includes realistic business conditions such as cancellations, unavailable orders, late deliveries, repeat customers, split payments, missing product categories, and unmapped product categories. It does **not** intentionally include broken foreign keys or duplicate primary keys, so the constraint script can run after validation.
