#!/bin/sh
set -ex

export GOROOT=/usr/go

go build -ldflags "-w -s -X 'main.version=${MINIMAL_ARG_VERSION}'" -o bin_grype ./cmd/grype

mkdir -p $OUTPUT_DIR/usr/bin
install -m 755 bin_grype $OUTPUT_DIR/usr/bin/grype
