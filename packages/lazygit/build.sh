#!/bin/sh
# Imported from Wolfi `lazygit` (0.63.0, go) by pkgmgr import-wolfi.
set -eu
export GOROOT=/usr/go
go build -trimpath -ldflags "-buildid= -w -s -X main.version=${MINIMAL_ARG_VERSION} -X main.buildSource=wolfiRelease" -o lazygit .
mkdir -p "$OUTPUT_DIR/usr/bin"
install -m 755 lazygit "$OUTPUT_DIR/usr/bin/lazygit"
