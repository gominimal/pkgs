#!/bin/sh
# Auto-bootstrapped from https://github.com/go-swagger/go-swagger (0.36.6, go) by pkgmgr import github.
set -eux

# Entrypoint is ./cmd/swagger and upstream names the binary `swagger` —
# which is what the agentbox image expects on PATH.
export GOROOT=/usr/go
mkdir -p "$OUTPUT_DIR/usr/bin"
go build -trimpath -ldflags "-buildid= -w -s" -o "$OUTPUT_DIR/usr/bin/swagger" ./cmd/swagger
