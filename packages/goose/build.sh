#!/bin/sh
# Auto-bootstrapped from https://github.com/pressly/goose (3.28.0, go) by pkgmgr import github.
set -eux

# goose's entrypoint is ./cmd/goose; building the repo root emits a
# non-ELF artifact that trips the output-types checker.
export GOROOT=/usr/go
mkdir -p "$OUTPUT_DIR/usr/bin"
go build -trimpath -ldflags "-buildid= -w -s" -o "$OUTPUT_DIR/usr/bin/goose" ./cmd/goose
