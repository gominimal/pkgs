#!/bin/sh
set -ex

export GOROOT=/usr/go
# Deps are vendored in the source tree; build offline and never let the go
# command fetch a newer toolchain than the one we ship.
export GOTOOLCHAIN=local

go build -mod=vendor -trimpath -ldflags "-buildid= -w -s -X 'main.Version=${MINIMAL_ARG_VERSION}'" -o cloudflared ./cmd/cloudflared

mkdir -p $OUTPUT_DIR/usr/bin
install -m 755 cloudflared $OUTPUT_DIR/usr/bin/cloudflared
