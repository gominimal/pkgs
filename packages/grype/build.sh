#!/bin/sh
set -ex

# CS-builder offline path: hermetic-builder-rs stages the goproxy
# mirror at /state/cs-mirror/goproxy/ under MINIMAL_INTERNAL_CS_BUILD=1.
# Outside CS this dir doesn't exist; build falls back to default GOPROXY.
if [ -d /state/cs-mirror/goproxy ]; then
    export GOPROXY="file:///state/cs-mirror/goproxy"
    export GOSUMDB=off
fi

export GOROOT=/usr/go

go build -trimpath -ldflags "-buildid= -w -s -X 'main.version=${MINIMAL_ARG_VERSION}'" -o bin_grype ./cmd/grype

mkdir -p $OUTPUT_DIR/usr/bin
install -m 755 bin_grype $OUTPUT_DIR/usr/bin/grype
