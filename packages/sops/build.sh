#!/bin/sh
# Imported from Wolfi `sops` (3.13.2, go) by pkgmgr import-wolfi.
set -eu
export GOROOT=/usr/go
mkdir -p "$OUTPUT_DIR/usr/bin"
go build -trimpath -ldflags "-buildid= -w -s" -o "$OUTPUT_DIR/usr/bin/sops" ./cmd/sops
