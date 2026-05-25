#!/bin/bash
set -euo pipefail

# CS-builder offline path: hermetic-builder-rs stages the goproxy
# mirror at /goproxy/ under MINIMAL_INTERNAL_CS_BUILD=1.
# Outside CS this dir doesn't exist; build falls back to default GOPROXY.
if [ -d /goproxy ]; then
    export GOPROXY="file:///goproxy"
    export GOSUMDB=off
fi

export GOROOT=/usr/go
export CGO_ENABLED=0
export GONOSUMCHECK=*
export GONOSUMDB=*
export GOFLAGS="-mod=vendor"

go build -ldflags="-buildid=" -o $OUTPUT_DIR/usr/bin/kubectl ./cmd/kubectl/
