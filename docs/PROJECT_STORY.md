# Project Story

## Business scenario

A delivery/operations team receives batches of e-commerce transaction data from multiple source tables. Before those outputs can be used for client reporting, the analyst must confirm that the data is complete, internally consistent and financially reasonable.

## Objective

Build a SQL validation and reporting layer that:

1. checks incoming batch data for quality issues;
2. detects duplicates, missing keys, orphan records and invalid timestamps;
3. reconciles order-item totals against payment totals;
4. creates safe reusable reporting views;
5. measures fulfilment performance, cancellations, customer repeat behaviour and seller performance;
6. outputs a simple batch-quality scorecard and management KPIs.

## Workflow

**Raw CSVs → MySQL tables → quality checks → keys/indexes → clean views → business queries → KPI / batch-quality outputs**

## What makes the project reliable

The project avoids the common SQL mistake of joining several one-to-many tables directly. Items, payments and reviews are aggregated to one row per order first. This prevents payment and revenue duplication when producing order-level KPIs.

## Tools

- MySQL 8.0
- MySQL Workbench
- SQL: joins, CTEs, subqueries, CASE, aggregate functions, date logic, window functions, views and indexes
