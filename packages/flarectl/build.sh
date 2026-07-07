#!/bin/sh
set -ex

export GOROOT=/usr/go
export GONOSUMCHECK=*
export GONOSUMDB=*

go build -trimpath -ldflags "-buildid= -w -s -X 'main.version=${MINIMAL_ARG_VERSION}'" -o flarectl ./cmd/flarectl

mkdir -p $OUTPUT_DIR/usr/bin
install -m 755 flarectl $OUTPUT_DIR/usr/bin/flarectl
