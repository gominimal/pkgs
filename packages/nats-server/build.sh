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
export CGO_ENABLED=0

go build -trimpath \
  -ldflags="-w -buildid= -X github.com/nats-io/nats-server/v2/server.serverVersion=${MINIMAL_ARG_VERSION}" \
  -o nats-server .
install -D -m 0755 nats-server "$OUTPUT_DIR/usr/bin/nats-server"
