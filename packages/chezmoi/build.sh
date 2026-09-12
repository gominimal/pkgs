#!/bin/sh
# Imported from Wolfi `chezmoi` (2.71.0, go) by pkgmgr import-wolfi.
set -eu
export GOROOT=/usr/go
# Pipe (not comma): fall back to direct on ANY proxy error — see cosign's
# build.sh for the full story (pkgs#648: proxy.golang.org per-stream resets).
export GOPROXY="https://proxy.golang.org|direct"
mkdir -p "$OUTPUT_DIR/usr/bin"
go build -trimpath -ldflags "-buildid= -w -s -X main.version=${MINIMAL_ARG_VERSION}" -o "$OUTPUT_DIR/usr/bin/chezmoi" .
