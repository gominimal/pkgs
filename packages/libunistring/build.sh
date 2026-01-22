#!/bin/sh
set -e

export CFLAGS="-march=x86-64-v3 -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

./configure  --prefix=/usr          \
            --disable-static        \
            --docdir=/usr/share/doc/libunistring-1.3

make -j$(nproc)
make DESTDIR="$OUTPUT_DIR" install
