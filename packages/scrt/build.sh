#!/bin/sh
set -ex

export GOROOT=/usr/go
export GONOSUMCHECK=*
export GONOSUMDB=*

go build -o scrt .

install -D -m 0755 scrt "$OUTPUT_DIR/usr/bin/scrt"
