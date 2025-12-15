#!/bin/sh
set -e

./configure --prefix=/usr \
            --enable-hashes=strong,glibc \
            --enable-obsolete-api=no \
            --disable-static \
            --disable-failure-tokens

make -j$(nproc)
make check
make DESTDIR="$OUTPUT_DIR" install
