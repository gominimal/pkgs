#!/bin/sh
# Imported from Wolfi `stress-ng` (0.21.03, Makefile) by pkgmgr import-wolfi.
set -eu
# Reproducibility flags (see AGENTS.md).
export CFLAGS="${CFLAGS:-} -ffile-prefix-map=$(pwd)=/builddir -gno-record-gcc-switches"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="${LDFLAGS:-} -Wl,--build-id=none"
export ARFLAGS=Drc
export CC="${CC:-gcc}" CXX="${CXX:-g++}"
make -j"$(nproc)" PREFIX=/usr
make PREFIX=/usr DESTDIR="$OUTPUT_DIR" install
# Drop libtool archives — they embed absolute build-time paths.
find "$OUTPUT_DIR" -name '*.la' -delete
