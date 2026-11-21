#!/bin/sh
set -eu

export GOROOT=/usr/go
export CGO_ENABLED=0
export GONOSUMCHECK=*
export GONOSUMDB=*

go build -trimpath -ldflags "-buildid= -s -w -X main.version=${MINIMAL_ARG_VERSION}" -o vale ./cmd/vale

mkdir -p "$OUTPUT_DIR/usr/bin"
install -m 755 vale "$OUTPUT_DIR/usr/bin/vale"
