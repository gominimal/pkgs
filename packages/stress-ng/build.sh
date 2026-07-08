#!/bin/sh
# Imported from Wolfi `stress-ng` (0.21.03, Makefile) by pkgmgr import-wolfi.
set -eu
export CC="${CC:-gcc}" CXX="${CXX:-g++}"
make -j"$(nproc)" PREFIX=/usr
make PREFIX=/usr DESTDIR="$OUTPUT_DIR" install
