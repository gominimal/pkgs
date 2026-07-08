#!/bin/sh
# Imported from Wolfi `eslint` (10.6.0, node) by pkgmgr import-wolfi.
set -eu
npm install -g --prefix="$OUTPUT_DIR/usr" "eslint@$MINIMAL_ARG_VERSION"
