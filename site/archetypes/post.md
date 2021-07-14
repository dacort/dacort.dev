---
title: "{{ replace .Name "-" " " | title }}"
date: {{ .Date }}
draft: true

tags: ["aws"]
showToc: false

cover:
    image: "<image path/url>" # image path/url
    alt: "<alt text>" # alt text
    caption: "<text>" # display caption under cover
    relative: true # when using page bundles set this to true
    hidden: true # only hide on current single page
---
