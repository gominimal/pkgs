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

LDFLAGS="-buildid= -s -w -X github.com/spiffe/spire/pkg/common/version.gittag=${MINIMAL_ARG_VERSION}"

go build -trimpath -buildvcs=false -ldflags "$LDFLAGS" -o spire-server ./cmd/spire-server
go build -trimpath -buildvcs=false -ldflags "$LDFLAGS" -o spire-agent ./cmd/spire-agent
go build -trimpath -buildvcs=false -ldflags "$LDFLAGS" -o oidc-discovery-provider ./support/oidc-discovery-provider

mkdir -p $OUTPUT_DIR/usr/bin
install -m 755 spire-server $OUTPUT_DIR/usr/bin/spire-server
install -m 755 spire-agent $OUTPUT_DIR/usr/bin/spire-agent
install -m 755 oidc-discovery-provider $OUTPUT_DIR/usr/bin/oidc-discovery-provider
