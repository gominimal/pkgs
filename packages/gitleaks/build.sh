#!/bin/sh
# Imported from Wolfi `gitleaks` (8.30.1, go) by pkgmgr import-wolfi.
set -eu
export GOROOT=/usr/go
mkdir -p "$OUTPUT_DIR/usr/bin"
go build -trimpath -ldflags "-buildid= -w -s -X github.com/gitleaks/gitleaks/v8/cmd.Version=${MINIMAL_ARG_VERSION}" -o "$OUTPUT_DIR/usr/bin/gitleaks" .
