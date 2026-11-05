#!/bin/sh
# Imported from Wolfi `libassuan` (3.0.2, autotools) by pkgmgr import wolfi.
# TODO: REVIEWER — the Wolfi recipe passed no configure opts; add any this
# build needs (check upstream INSTALL).
set -eu
# Reproducibility flags (see AGENTS.md).
export CFLAGS="${CFLAGS:-} -ffile-prefix-map=$(pwd)=/builddir -gno-record-gcc-switches"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="${LDFLAGS:-} -Wl,--build-id=none"
export ARFLAGS=Drc
if [ ! -x ./configure ]; then autoreconf -fi; fi
./configure --prefix=/usr --enable-deterministic-archives
make MAKEINFO=true -j"$(nproc)"
make MAKEINFO=true DESTDIR="$OUTPUT_DIR" install
# Drop libtool archives — they embed absolute build-time paths.
find "$OUTPUT_DIR" -name '*.la' -delete
# The sandbox seeds $OUTPUT_DIR/usr/lib64 -> lib so lib64 installs land in
# usr/lib. Our usr/** output glob would ship that symlink (followed, it also
# duplicates every library under a real usr/lib64/). One package shipping
# usr/lib64 as a symlink and another as a directory is a path collision in any
# sandbox holding both; the order is spec-hash-dependent, and the wrong order is
# a hard "File exists" (gnupg's smoke test, pkgs#1242). Libraries live in usr/lib.
rm -f "$OUTPUT_DIR/usr/lib64"
