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

go build -trimpath -ldflags "-buildid= -w -s -X 'sigs.k8s.io/release-utils/version.gitVersion=v${MINIMAL_ARG_VERSION}'" -o cosign ./cmd/cosign

mkdir -p $OUTPUT_DIR/usr/bin
install -m 755 cosign $OUTPUT_DIR/usr/bin/cosign
