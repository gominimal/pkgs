#!/bin/sh
set -ex

export GOROOT=/usr/go

go build -ldflags="-buildid=" -o jqfmt ./cmd/jqfmt
install -D -m 0755 jqfmt "$OUTPUT_DIR/usr/bin/jqfmt"
