#!/bin/bash
set -euo pipefail

export GOROOT=/usr/go
# Pipe (not comma) separator: fall back to direct on ANY proxy error (see
# grpcurl/build.sh, pkgs#648). go.sum still verifies every module fetched.
export GOPROXY="https://proxy.golang.org|direct"
# Static, as upstream's release build (.goreleaser.yml) does.
export CGO_ENABLED=0

cd "toxiproxy-$MINIMAL_ARG_VERSION"

# Upstream stamps the version the same way (.goreleaser.yml ldflags).
ldflags="-s -w -buildid= -X github.com/Shopify/toxiproxy/v2.Version=$MINIMAL_ARG_VERSION"
go build -trimpath -ldflags="$ldflags" -o toxiproxy-server ./cmd/server
go build -trimpath -ldflags="$ldflags" -o toxiproxy-cli ./cmd/cli

install -D -m 0755 toxiproxy-server "$OUTPUT_DIR/usr/bin/toxiproxy-server"
install -D -m 0755 toxiproxy-cli "$OUTPUT_DIR/usr/bin/toxiproxy-cli"
