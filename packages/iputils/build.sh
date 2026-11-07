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
# The sandbox seeds $OUTPUT_DIR/usr/lib64 -> lib so lib64 installs land in
# usr/lib. Our usr/** output glob would ship that symlink (followed, it also
# duplicates every library under a real usr/lib64/). One package shipping
# usr/lib64 as a symlink and another as a directory is a path collision in any
# sandbox holding both; the order is spec-hash-dependent, and the wrong order is
# a hard "File exists" (gnupg's smoke test, pkgs#1242). Libraries live in usr/lib.
rm -f "$OUTPUT_DIR/usr/lib64"
