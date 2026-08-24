#!/bin/sh
# Imported from Wolfi `chezmoi` (2.71.0, go) by pkgmgr import-wolfi.
set -eu
export GOROOT=/usr/go
mkdir -p "$OUTPUT_DIR/usr/bin"
go build -trimpath -ldflags "-buildid= -w -s -X main.version=${MINIMAL_ARG_VERSION}" -o "$OUTPUT_DIR/usr/bin/chezmoi" .
