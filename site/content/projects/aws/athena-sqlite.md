---
title: "Athena SQLite 💾 "
description: ""
lead: ""
date: 2021-05-14T15:23:33-07:00
lastmod: 2021-05-14T15:23:33-07:00
draft: false
weight: 150
---

Athena SQLite is a project that allows you to query SQLite databases in S3 using Athena's Federated Query functionality.

Install it from the Serverless Application Repository: [AthenaSQLiteConnector](https://serverlessrepo.aws.amazon.com/#/applications/arn:aws:serverlessrepo:us-east-1:689449560910:applications~AthenaSQLITEConnector).


## Wait, what?!

SQLite in S3? Yea! As quite possibly the most prevelant database in the world, it's not unsual for me to have various SQLite files laying around.

This Athena data connector allows you to query those databases directly from Athena.

## Cool!

Right?! One of the fun things about this project is that SQLite is *not* intended to be a network database.

So I implemented a custom [Virtual File System](https://rogerbinns.github.io/apsw/vfs.html) for S3 that could be used by the Python SQLite wrapper, [APSW](https://rogerbinns.github.io/apsw/).

## Source Code

[dacort/athena-sqlite](https://github.com/dacort/athena-sqlite/)