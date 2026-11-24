#!/bin/bash
set -euo pipefail

export GOROOT=/usr/go
# Pipe (not comma) separator: fall back to direct on ANY proxy error (see
# grpcurl/build.sh, pkgs#648). go.sum still verifies every module fetched.
export GOPROXY="https://proxy.golang.org|direct"
# Static, as upstream's release build (.goreleaser.yml) builds cmd/ghz.
export CGO_ENABLED=0

cd "ghz-$MINIMAL_ARG_VERSION"

# Upstream stamps the version the same way (goreleaser's main.version).
go build -trimpath \
    -ldflags="-s -w -buildid= -X main.version=$MINIMAL_ARG_VERSION" \
    -o ghz ./cmd/ghz

install -D -m 0755 ghz "$OUTPUT_DIR/usr/bin/ghz"
