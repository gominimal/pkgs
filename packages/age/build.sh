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
go build -trimpath -o 'age' -ldflags "-buildid= -X main.Version=$MINIMAL_ARG_VERSION" ./cmd/age
install -D -m 0755 age "$OUTPUT_DIR/usr/bin/age"

go build -trimpath -o 'age-keygen' -ldflags "-buildid= -X main.Version=$MINIMAL_ARG_VERSION" ./cmd/age-keygen
install -D -m 0755 age-keygen "$OUTPUT_DIR/usr/bin/age-keygen"
