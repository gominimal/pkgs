#!/bin/sh
set -ex

export GOROOT=/usr/go

go build -ldflags "-w -s -X 'github.com/cli/cli/v2/internal/build.Version=${MINIMAL_ARG_VERSION}'" -o gh ./cmd/gh

mkdir -p $OUTPUT_DIR/usr/bin
install -m 755 gh $OUTPUT_DIR/usr/bin/gh
