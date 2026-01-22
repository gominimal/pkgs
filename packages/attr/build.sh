#!/bin/sh
set -e

export CFLAGS="-march=x86-64-v3 -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

./configure  --prefix=/usr      \
            --disable-static    \
            --sysconfdir=/etc   \
            --docdir=/usr/share/doc/attr-2.5.2

make -j$(nproc)
# make check # TODO
make DESTDIR="$OUTPUT_DIR" install
