#!/bin/sh
# Imported from Wolfi `pathspec` (1.1.1, python) by pkgmgr import-wolfi.
set -eu
pip3 wheel -w dist --no-build-isolation --no-deps --no-cache-dir "$(pwd)"
pip3 install --no-index --find-links dist --no-deps --no-user --root "$OUTPUT_DIR" pathspec
