#!/bin/sh

if [ -z "$1" ]; then
    echo "Usage: $0 <url-slug>"
    exit 1
fi

hugo new --kind post posts/$1/index.md