#!/bin/sh
# Imported from Wolfi `gitleaks` (8.30.1, go) by pkgmgr import-wolfi.
set -eu
export GOROOT=/usr/go
mkdir -p "$OUTPUT_DIR/usr/bin"
# Version var lives in the `version` package and the module path kept the
# original `zricethezav` org (per upstream .goreleaser.yml) despite the GitHub
# org rename to gitleaks/gitleaks — a wrong path is silently ignored by the linker.
go build -trimpath -ldflags "-buildid= -w -s -X github.com/zricethezav/gitleaks/v8/version.Version=${MINIMAL_ARG_VERSION}" -o "$OUTPUT_DIR/usr/bin/gitleaks" .
