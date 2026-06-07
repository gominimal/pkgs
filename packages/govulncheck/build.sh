#!/bin/sh
set -ex

# CS-builder offline path: hermetic-builder-rs hydrates the goproxy
# mirror at /goproxy. Outside CS this dir doesn't exist; the build
# falls back to the default GOPROXY.
if [ -d /goproxy ]; then
    export GOPROXY="file:///goproxy"
    export GOSUMDB=off
fi

export GOROOT=/usr/go
export GONOSUMCHECK=*
export GONOSUMDB=*
export CGO_ENABLED=0

cd vuln-$MINIMAL_ARG_VERSION

go build -ldflags="-s -w -buildid=" -o $OUTPUT_DIR/usr/bin/govulncheck ./cmd/govulncheck
