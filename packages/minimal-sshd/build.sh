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

go mod tidy
CGO_ENABLED=0 go build -trimpath -ldflags "-buildid= -w -s" -o minimal-sshd .

mkdir -p $OUTPUT_DIR/usr/bin
install -m 755 minimal-sshd $OUTPUT_DIR/usr/bin/minimal-sshd
