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
export GOTOOLCHAIN=local
# Pipe (not comma) separator: fall back to direct on ANY proxy error —
# proxy.golang.org sheds load with per-stream RST(INTERNAL_ERROR) under
# module-burst, go does not retry, and the comma form only falls back on
# 404/410 (pkgs#648). GUARDED so the CS offline file:///goproxy set above
# is never clobbered.
[ -n "${GOPROXY:-}" ] || export GOPROXY="https://proxy.golang.org|direct"

LDFLAGS="-buildid= -s -w -X github.com/spiffe/spire/pkg/common/version.gittag=${MINIMAL_ARG_VERSION}"

go build -trimpath -buildvcs=false -ldflags "$LDFLAGS" -o spire-server ./cmd/spire-server
go build -trimpath -buildvcs=false -ldflags "$LDFLAGS" -o spire-agent ./cmd/spire-agent
go build -trimpath -buildvcs=false -ldflags "$LDFLAGS" -o oidc-discovery-provider ./support/oidc-discovery-provider

mkdir -p $OUTPUT_DIR/usr/bin
install -m 755 spire-server $OUTPUT_DIR/usr/bin/spire-server
install -m 755 spire-agent $OUTPUT_DIR/usr/bin/spire-agent
install -m 755 oidc-discovery-provider $OUTPUT_DIR/usr/bin/oidc-discovery-provider
