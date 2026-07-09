#!/bin/sh
# Imported from Wolfi `act` (0.2.89, go) by pkgmgr import-wolfi.
set -eu
export GOROOT=/usr/go
# Stamp the version so `act --version` reports it (act reads `main.version`);
# $MINIMAL_ARG_VERSION is forwarded from build.ncl's `version` via build_args.
go build -trimpath -ldflags "-buildid= -w -s -X main.version=${MINIMAL_ARG_VERSION}" -o act .
mkdir -p "$OUTPUT_DIR/usr/bin"
install -m 755 act "$OUTPUT_DIR/usr/bin/act"
