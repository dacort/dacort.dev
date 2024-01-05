---
title: "Developer Experience tools for Amazon EMR"
description: ""
lead: "Different tools I've created to make using EMR easier."
date: 2024-01-05T08:58:00-07:00
lastmod: 2021-05-14T08:58:00-07:00
draft: false
weight: 150
---

As part of my role as a developer advocate, I've created several different open source tools or integrations to make working with Amazon EMR easier for data engineers and other data wranglers.

## Amazon EMR CLI

The [EMR CLI](https://github.com/awslabs/amazon-emr-cli) is an open-source command-line interface that makes packaging, deploying, and running jobs across all EMR deployment models as simple as an `emr run`. The tool supports PySpark projects and automatically bundles the required dependencies in a consistent manner no matter whether you're using EMR on EC2, EMR on EKS (coming soon), or EMR Serverless. It also adds additional features like log-tailing, job monitoring, and bootstrapping of dev environments.

## Amazon EMR Toolkit for VS Code

I also built an [EMR extension for VS Code](https://marketplace.visualstudio.com/items?itemName=AmazonEMR.emr-tools) that improves the feedback loop for Spark developers using EMR. Instead of having to test code on remote clusters, the extension allows you to create a local EMR environment where you can quickly iterate on changes before deploying the code to your test or production environments. It also allows you to manage your different EMR environments and includes a Glue Data Catalog viewer.

## EMR Serverless Samples

To make it easier for folks to have production-ready examples of different code, deployment templates, and monitoring dashboards for EMR Serverless, I created the [EMR Serverless Samples](https://github.com/aws-samples/emr-serverless-samples) repository. The repository is a central source of up-to-date references for folks using EMR Serverless.