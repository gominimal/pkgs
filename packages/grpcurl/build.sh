#!/bin/sh
set -ex

export GOROOT=/usr/go
go build -o 'grpcurl' ./cmd/grpcurl
install -D -m 0755 grpcurl "$OUTPUT_DIR/usr/bin/grpcurl"
