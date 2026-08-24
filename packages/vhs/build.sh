#!/bin/sh
# Auto-bootstrapped from https://github.com/charmbracelet/vhs (0.11.0, go) by pkgmgr import-wolfi.
set -eu
export GOROOT=/usr/go
mkdir -p "$OUTPUT_DIR/usr/bin"
go build -trimpath -ldflags "-buildid= -w -s" -o "$OUTPUT_DIR/usr/bin/vhs" .
