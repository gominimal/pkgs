#!/bin/sh
set -ex

export GOROOT=/usr/go

go build -o mermaid-ascii ./
install -D -m 0755 mermaid-ascii "$OUTPUT_DIR/usr/bin/mermaid-ascii"
