#!/bin/sh
# Imported from Wolfi `mkcert` (1.4.4, go) by pkgmgr import-wolfi.
set -eu
export GOROOT=/usr/go
go build -trimpath -ldflags "-buildid= -w -s -X main.Version=${MINIMAL_ARG_VERSION}" -o mkcert .
mkdir -p "$OUTPUT_DIR/usr/bin"
install -m 755 mkcert "$OUTPUT_DIR/usr/bin/mkcert"
