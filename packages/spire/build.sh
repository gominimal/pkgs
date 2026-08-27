#!/bin/sh
set -ex

export GOROOT=/usr/go
# Pipe (not comma): fall back to direct on ANY proxy error — see cosign's
# build.sh for the full story (pkgs#648: proxy.golang.org per-stream resets).
export GOPROXY="https://proxy.golang.org|direct"

LDFLAGS="-buildid= -s -w -X github.com/spiffe/spire/pkg/common/version.gittag=${MINIMAL_ARG_VERSION}"

go build -trimpath -buildvcs=false -ldflags "$LDFLAGS" -o spire-server ./cmd/spire-server
go build -trimpath -buildvcs=false -ldflags "$LDFLAGS" -o spire-agent ./cmd/spire-agent
go build -trimpath -buildvcs=false -ldflags "$LDFLAGS" -o oidc-discovery-provider ./support/oidc-discovery-provider

mkdir -p $OUTPUT_DIR/usr/bin
install -m 755 spire-server $OUTPUT_DIR/usr/bin/spire-server
install -m 755 spire-agent $OUTPUT_DIR/usr/bin/spire-agent
install -m 755 oidc-discovery-provider $OUTPUT_DIR/usr/bin/oidc-discovery-provider
