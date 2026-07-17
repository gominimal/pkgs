#!/bin/sh
# BuDDy — standard automake, but the release tarball ships configure/install-sh
# WITHOUT the execute bit (noted in Maude's INSTALL), so restore it first. C++.
set -e

chmod +x configure install-sh 2>/dev/null || true

export CFLAGS="-O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="-Wl,--build-id=none"

./configure \
    --prefix=/usr \
    --enable-shared \
    --disable-static \
    --enable-deterministic-archives

make -j"$(nproc)"
make DESTDIR="$OUTPUT_DIR" install

find "$OUTPUT_DIR" -name '*.la' -delete
