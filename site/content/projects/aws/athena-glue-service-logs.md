---
title: "Athena Glue Service Logs"
description: "Glue jobs and library to manage conversion of AWS Service Logs into Athena-friendly formats."
date: 2021-05-14T15:23:33-07:00
lastmod: 2021-05-14T15:23:33-07:00
draft: false
images: []
weight: 150
showToc: false
---

AWS Service Logs come in all different formats. Ideally they could all be queried in place by Athena and, while some can, for cost and performance reasons it can be better to convert the logs into partitioned Parquet files.

The general approach is that for any given type of service log, we have Glue Jobs that can do the following:
1. Create source tables in the Data Catalog
2. Create destination tables in the Data Catalog
3. Know how to convert the source data to partitioned, Parquet files
4. Maintain new partitions for both tables

This library was created as part of my role as a Big Data Architect and is available at [awslabs/athena-glue-service-logs](https://github.com/awslabs/athena-glue-service-logs).