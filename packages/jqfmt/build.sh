#!/bin/sh
set -ex

# CS-builder offline path: hermetic-builder-rs stages the goproxy
# mirror at /goproxy/ under MINIMAL_INTERNAL_CS_BUILD=1.
# Outside CS this dir doesn't exist; build falls back to default GOPROXY.
if [ -d /goproxy ]; then
    export GOPROXY="file:///goproxy"
    export GOSUMDB=off
fi

export GOROOT=/usr/go

go build -ldflags="-buildid=" -o jqfmt ./cmd/jqfmt
install -D -m 0755 jqfmt "$OUTPUT_DIR/usr/bin/jqfmt"
