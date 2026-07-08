#!/bin/sh
# Imported from Wolfi `trove-classifiers` (2026.6.1.19, python) by pkgmgr import-wolfi.
set -eu
export SETUPTOOLS_SCM_PRETEND_VERSION="$MINIMAL_ARG_VERSION"
pip3 wheel -w dist --no-build-isolation --no-deps --no-cache-dir "$(pwd)"
pip3 install --no-index --find-links dist --no-deps --no-user --root "$OUTPUT_DIR" trove-classifiers
