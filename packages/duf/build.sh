#!/bin/sh
set -ex

export GOROOT=/usr/go

go build -ldflags "-w -s" -o duf .

mkdir -p $OUTPUT_DIR/usr/bin
install -m 755 duf $OUTPUT_DIR/usr/bin/duf
