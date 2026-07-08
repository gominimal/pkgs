#!/bin/sh
# Imported from Wolfi `json-server` (0.17.4, node) by pkgmgr import-wolfi.
set -eu
npm install -g --prefix="$OUTPUT_DIR/usr" "json-server@$MINIMAL_ARG_VERSION"
