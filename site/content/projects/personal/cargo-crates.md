---
title: "Cargo Crates 🚚"
description: "An easy way to extract data with Containers."
lead: "An easy way to extract data with Containers."
date: 2021-05-14T08:49:31+00:00
lastmod: 2021-05-14T08:49:31+00:00
draft: false
weight: 250
---

All good ideas start with a Tweet. 😁

{{< tweet user="dacort" id="1359638593812140032" >}}

I'm often hopping around to different APIs and only want a slice of data. And I get frustrated with having to:
- Find the right API client
- Reimplement authentication
- Store credentials in different places
- Maintain it

And so on, and so on. So I made a simple framework on Docker that provides a pattern for accessing remote APIs in a consistent manner.

## Installation

> That sounds pretty cool, how do I use it?

You just need Docker and credentials for any supported API. I've got [several examples on fetching data](https://github.com/dacort/cargo-crates#supported-services) in the README, but let's say you have a GitHub Personal Access Token and want to fetch traffic stats for a repo.

```shell
docker run -e GITHUB_PAT \
    ghcr.io/dacort/crates-github \
    traffic dacort/cargo-crates 
```

You get a stream of JSON data back.

```json
{"repo": "dacort/cargo-crates", "path": "clones", "stats": {"count": 77, "uniques": 8, "clones": [{"timestamp": "2021-03-18T00:00:00Z", "count": 77, "uniques": 8}]}}
{"repo": "dacort/cargo-crates", "path": "popular/paths", "stats": [{"path": "/dacort/cargo-crates/actions", "title": "Actions \u00b7 dacort/cargo-crates", "count": 33, "uniques": 1}, {"path": "/dacort/cargo-crates", "title": "dacort/cargo-crates", "count": 11, "uniques": 2}, {"path": "/dacort/cargo-crates/actions/workflows/crates.yaml", "title": "Actions \u00b7 dacort/cargo-crates", "count": 7, "uniques": 1}, {"path": "/dacort/cargo-crates/actions/runs/666130915", "title": "Remove useless job0 \u00b7 dacort/cargo-crates@6b54337", "count": 4, "uniques": 1}, {"path": "/dacort/cargo-crates/actions/runs/666151009", "title": "Trying something else \u00b7 dacort/cargo-crates@ed3d226", "count": 3, "uniques": 1}, {"path": "/dacort/cargo-crates/actions/runs/666165537", "title": "Hmm \u00b7 dacort/cargo-crates@64c59e7", "count": 3, "uniques": 1}, {"path": "/dacort/cargo-crates/actions/runs/666215936", "title": "Add requirements \u00b7 dacort/cargo-crates@6161093", "count": 3, "uniques": 1}, {"path": "/dacort/cargo-crates/actions/runs/666227882", "title": "Does this actually work now?? \u00b7 dacort/cargo-crates@37d31ea", "count": 3, "uniques": 1}, {"path": "/dacort/cargo-crates/pulls", "title": "Pull requests \u00b7 dacort/cargo-crates", "count": 3, "uniques": 1}, {"path": "/dacort/cargo-crates/actions/workflows/test_matrix.yaml", "title": "Actions \u00b7 dacort/cargo-crates", "count": 2, "uniques": 1}]}
{"repo": "dacort/cargo-crates", "path": "popular/referrers", "stats": [{"referrer": "github.com", "count": 3, "uniques": 2}]}
{"repo": "dacort/cargo-crates", "path": "views", "stats": {"count": 108, "uniques": 2, "views": [{"timestamp": "2021-03-18T00:00:00Z", "count": 108, "uniques": 2}]}}
```

## Now what?

- Well, you could run it through `jq` to do some quick analysis...

Let's look at our Oura data, for example, to see what night this year I got the most sleep.

```shell
# Extract Oura sleep data and show my most restful night of the year
docker run -e OURA_PAT \
    -e start=2021-01-01 \
    ghcr.io/dacort/crates-oura \
    | jq -rs '. | max_by(.deep) | [.bedtime_start][0]'
```

```
2021-03-21T00:13:18-07:00
```

- Every "Cargo Crate" also comes with a [forklift](https://github.com/dacort/forklift) (_haha get it?_) that can be used to stream the data to arbitrary locations on S3.

By adding a `FORKLIFT_URI` environment variable, we can write our sleep data to a location based on the Y-m-d of `bedtime_start`.

```shell
docker run \
    -e OURA_PAT \
    -e AWS_ACCESS_KEY_ID \
    -e AWS_SECRET_ACCESS_KEY \
    -e FORKLIFT_URI='s3://<BUCKET>/forklift/oura/{{json "bedtime_start" | getYMDFromISO }}/sleep_data.json' \
    ghcr.io/dacort/crates-oura sleep
```

```
2021/06/16 17:09:39 Connecting to S3 with template: s3://<BUCKET>/forklift/oura/{{json "bedtime_start" | getYMDFromISO }}/sleep_data.json
2021/06/16 17:09:40 Creating new S3 output file: s3://<BUCKET>/forklift/oura/2021-06-10/sleep_data.json
2021/06/16 17:09:40 Creating new S3 output file: s3://<BUCKET>/forklift/oura/2021-06-11/sleep_data.json
2021/06/16 17:09:40 Creating new S3 output file: s3://<BUCKET>/forklift/oura/2021-06-12/sleep_data.json
2021/06/16 17:09:40 Creating new S3 output file: s3://<BUCKET>/forklift/oura/2021-06-13/sleep_data.json
2021/06/16 17:09:40 Creating new S3 output file: s3://<BUCKET>/forklift/oura/2021-06-14/sleep_data.json
2021/06/16 17:09:40 Creating new S3 output file: s3://<BUCKET>/forklift/oura/2021-06-15/sleep_data.json
```