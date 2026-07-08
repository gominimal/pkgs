#!/bin/sh
# Imported from Wolfi `serve` (14.2.6, node) by pkgmgr import-wolfi.
set -eu
npm install -g --prefix="$OUTPUT_DIR/usr" "serve@$MINIMAL_ARG_VERSION"
