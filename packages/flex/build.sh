#!/bin/sh
set -e

tar xfo flex-2.6.4.tar.gz
cd flex-2.6.4

export CFLAGS="-march=x86-64-v3 -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

./configure  --prefix=/usr \
            --docdir=/usr/share/doc/flex-2.6.4 \
            --disable-static

make -j$(nproc)
make check
make DESTDIR=$OUTPUT_DIR install
