#!/bin/sh
set -ex


export GOROOT=/usr/go
go build -o 'age' -ldflags "-X main.Version=$MINIMAL_ARG_VERSION" ./cmd/age
install -D -m 0755 age "$OUTPUT_DIR/usr/bin/age"
