---
title: "Log4j.us 🪵"
description: "Dynamic log4j config generator."
lead: "Dynamic log4j config generator."
date: 2021-05-14T08:49:31+00:00
lastmod: 2021-05-14T08:49:31+00:00
draft: false
weight: 250
---

I made this while working at [Metabase](https://www.metabase.com/). As the Head of Success Engineering, I was often tasked with helping customers reproduce various edge cases. As part of this, we often needed more logs. The classes I wanted to enable `DEBUG` logs for *also* often differed depending on the specific situation the customer was encountering. 

💁 Did you know that log4j supports loading a configuration from an https URL? I didn't.

So I built a site you can pass to `-Dlog4j.configuration` with dynamic log levels.

✅ Want to start a basic jar with console `DEBUG` logging? Cool.

```shell
java -Dlog4j.configuration=https://log4j.us/templates/consoledebug -jar app.jar
```

✅ Want to enable `TRACE` logging for a certain namespace? Cool.

```shell
java -Dlog4j.configuration=https://log4j.us/templates/consoledebug?trace=some.namespace -jar app.jar
```

I've been meaning to add other templates, but for now it just supports the basic template and a Metabase one.

If you'd like to add other templates, feel free to submit a [pull request](https://github.com/dacort/log4j-us/).