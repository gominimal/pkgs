#!/bin/sh
# Imported from Wolfi `esbuild` (0.28.1, go) by pkgmgr import-wolfi.
set -eu
export GOROOT=/usr/go
mkdir -p "$OUTPUT_DIR/usr/bin"
go build -trimpath -ldflags "-buildid= -w -s" -o "$OUTPUT_DIR/usr/bin/esbuild" ./cmd/esbuild
