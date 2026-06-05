#!/bin/sh
set -ex

export GOROOT=/usr/go
export GONOSUMCHECK=*
export GONOSUMDB=*
export CGO_ENABLED=0

cd vuln-$MINIMAL_ARG_VERSION

go build -ldflags="-s -w -buildid=" -o $OUTPUT_DIR/usr/bin/govulncheck ./cmd/govulncheck
