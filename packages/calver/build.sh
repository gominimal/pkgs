#!/bin/sh
# Imported from Wolfi `calver` (2025.10.20, python) by pkgmgr import-wolfi.
set -eu
pip3 wheel -w dist --no-build-isolation --no-deps --no-cache-dir "$(pwd)"
pip3 install --no-index --find-links dist --no-deps --no-user --root "$OUTPUT_DIR" calver
