#!/bin/bash
# libsigsegv — standard GNU autotools. Source is pre-extracted (extract=true),
# so we configure in-tree. Shared lib only (Maude links it dynamically).
set -euo pipefail

export CFLAGS="-O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"

./configure \
    --prefix=/usr \
    --enable-shared \
    --disable-static \
    --enable-deterministic-archives

make -j"$(nproc)"
make DESTDIR="$OUTPUT_DIR" install

# Drop libtool archives — they embed absolute build-time paths.
find "$OUTPUT_DIR" -name '*.la' -delete
