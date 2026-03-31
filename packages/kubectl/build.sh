#!/bin/bash
set -euo pipefail

export GOROOT=/usr/go
export CGO_ENABLED=0
export GONOSUMCHECK=*
export GONOSUMDB=*
export GOFLAGS="-mod=vendor"

go build -ldflags="-buildid=" -o $OUTPUT_DIR/usr/bin/kubectl ./cmd/kubectl/
