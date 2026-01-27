#!/bin/sh
set -ex

export GOROOT=/usr/go

go build -ldflags "-w -s -X 'main.version=${MINIMAL_ARG_VERSION}'" -o bin_syft ./cmd/syft

mkdir -p $OUTPUT_DIR/usr/bin
install -m 755 bin_syft $OUTPUT_DIR/usr/bin/syft
