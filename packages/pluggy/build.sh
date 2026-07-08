#!/bin/sh
# Imported from Wolfi `pluggy` (1.6.0, python) by pkgmgr import-wolfi.
set -eu
export SETUPTOOLS_SCM_PRETEND_VERSION="1.6.0"
pip3 wheel -w dist --no-build-isolation --no-deps --no-cache-dir "$(pwd)"
pip3 install --no-index --find-links dist --no-deps --no-user --root "$OUTPUT_DIR" pluggy
