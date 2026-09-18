#!/bin/sh
# Imported from Wolfi `iputils` (20250605, meson) by pkgmgr import wolfi.
# TODO: REVIEWER — the Wolfi recipe passed no configure opts; add any this
# build needs (check upstream INSTALL).
set -eu
# Reproducibility flags (see AGENTS.md).
export CFLAGS="${CFLAGS:-} -ffile-prefix-map=$(pwd)=/builddir -gno-record-gcc-switches"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="${LDFLAGS:-} -Wl,--build-id=none"
export ARFLAGS=Drc
meson setup build --prefix=/usr --buildtype=release
meson compile -C build
DESTDIR="$OUTPUT_DIR" meson install -C build
