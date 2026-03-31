#!/bin/sh
set -ex

export GOROOT=/usr/go

go build -trimpath -ldflags "-buildid= -w -s" -o caddy ./cmd/caddy

mkdir -p $OUTPUT_DIR/usr/bin
install -m 755 caddy $OUTPUT_DIR/usr/bin/caddy
