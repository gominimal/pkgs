#!/bin/sh
# Imported from Wolfi `httpie` (3.2.4, python) by pkgmgr import wolfi.
set -eu
# Reproducibility for the compiled C extension (see AGENTS.md).
export CFLAGS="${CFLAGS:-} -ffile-prefix-map=$(pwd)=/builddir -gno-record-gcc-switches"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="${LDFLAGS:-} -Wl,--build-id=none"
pip3 wheel -w dist --no-build-isolation --no-deps --no-cache-dir "$(pwd)"
pip3 install --no-index --find-links dist --no-deps --no-user --prefix=/usr --root "$OUTPUT_DIR" httpie
