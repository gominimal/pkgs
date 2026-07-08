#!/bin/sh
# Imported from Wolfi `lerna` (9.0.7, node) by pkgmgr import-wolfi.
set -eu
npm install -g --prefix="$OUTPUT_DIR/usr" "lerna@$MINIMAL_ARG_VERSION"
