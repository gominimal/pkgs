#!/bin/sh
# Imported from Wolfi `act` (0.2.89, go) by pkgmgr import-wolfi.
set -eu
export GOROOT=/usr/go
go build -trimpath -ldflags "-buildid= -w -s" -o act .
mkdir -p "$OUTPUT_DIR/usr/bin"
install -m 755 act "$OUTPUT_DIR/usr/bin/act"
