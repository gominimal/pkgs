#!/bin/sh
set -ex

export GOROOT=/usr/go

go build -o glow
install -D -m 0755 glow "$OUTPUT_DIR/usr/bin/glow"
