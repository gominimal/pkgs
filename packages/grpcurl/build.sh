#!/bin/sh
set -ex

export GOROOT=/usr/go
# Pipe (not comma) separator: fall back to direct on ANY proxy error.
# proxy.golang.org sheds load with per-stream RST(INTERNAL_ERROR) under
# module-burst (hundreds of multiplexed fetches), go does not retry, and
# the comma form only falls back on 404/410 -- pkgs#648 failed 5 runs on it.
export GOPROXY="https://proxy.golang.org|direct"
go build -ldflags="-buildid=" -o 'grpcurl' ./cmd/grpcurl
install -D -m 0755 grpcurl "$OUTPUT_DIR/usr/bin/grpcurl"
