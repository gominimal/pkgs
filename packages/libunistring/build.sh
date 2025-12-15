#!/bin/sh
set -e

./configure  --prefix=/usr          \
            --disable-static        \
            --docdir=/usr/share/doc/libunistring-1.3

make -j$(nproc)
make DESTDIR="$OUTPUT_DIR" install
