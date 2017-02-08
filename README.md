# YAAP
Yet Another (Bash) Argument Parser

Clone the project and set environment variable `$YAAP` to point to the directory. Follwoing is a sample code that shows how you can use YAAP:

```
#! /bin/bash

$YAAP/init.sh

declare_bool boolarg "boolarg description" FALSE
declare_int intarg "intarg description" 128
declare_str strarg "strarg description" "4k"

init "$@"
```
