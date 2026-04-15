#!/bin/sh
set -ex

export GOROOT=/usr/go
export GONOSUMCHECK=*
export GONOSUMDB=*
export CGO_ENABLED=0

go build -trimpath \
  -ldflags="-w -buildid= -X github.com/nats-io/nats-server/v2/server.serverVersion=${MINIMAL_ARG_VERSION}" \
  -o nats-server .
install -D -m 0755 nats-server "$OUTPUT_DIR/usr/bin/nats-server"
