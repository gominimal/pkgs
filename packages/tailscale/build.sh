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
export GONOSUMCHECK=*
export GONOSUMDB=*

go build -trimpath -ldflags "-buildid= -w -s -X 'tailscale.com/version.shortStamp=${MINIMAL_ARG_VERSION}' -X 'tailscale.com/version.longStamp=${MINIMAL_ARG_VERSION}'" -o tailscale ./cmd/tailscale
go build -trimpath -ldflags "-buildid= -w -s -X 'tailscale.com/version.shortStamp=${MINIMAL_ARG_VERSION}' -X 'tailscale.com/version.longStamp=${MINIMAL_ARG_VERSION}'" -o tailscaled ./cmd/tailscaled

mkdir -p $OUTPUT_DIR/usr/bin $OUTPUT_DIR/usr/sbin
install -m 755 tailscale $OUTPUT_DIR/usr/bin/tailscale
install -m 755 tailscaled $OUTPUT_DIR/usr/sbin/tailscaled
