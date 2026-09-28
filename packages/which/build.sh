#!/bin/sh
set -ex

# Reproducibility flags per pkgs AGENTS.md: strip the build path out of any
# recorded string, drop the build-id, and make ar deterministic.
export CFLAGS="${CFLAGS:-} -ffile-prefix-map=$(pwd)=/builddir -gno-record-gcc-switches"
export LDFLAGS="${LDFLAGS:-} -Wl,--build-id=none"
export ARFLAGS="Drc"

./configure --prefix=/usr --enable-deterministic-archives
make -j"$(nproc)"
make install DESTDIR="$OUTPUT_DIR"

# autotools drops libtool archives that reference the build dir; they would
# make the output non-reproducible and are useless for a single binary.
rm -f "$OUTPUT_DIR"/usr/lib/*.la 2>/dev/null || true
