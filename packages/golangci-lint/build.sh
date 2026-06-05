#!/bin/sh
set -ex

export GOROOT=/usr/go
export GONOSUMCHECK=*
export GONOSUMDB=*
export CGO_ENABLED=0

cd golangci-lint-$MINIMAL_ARG_VERSION

go build -ldflags="-s -w -X main.version=$MINIMAL_ARG_VERSION -buildid=" -o $OUTPUT_DIR/usr/bin/golangci-lint ./cmd/golangci-lint
