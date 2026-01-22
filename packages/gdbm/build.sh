#!/bin/sh
set -e

tar xfo gdbm-1.26.tar.gz
cd gdbm-1.26

export CFLAGS="-march=x86-64-v3 -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

./configure --prefix=/usr \
            --disable-static \
            --enable-libgdbm-compat

make -j$(nproc)
#make check
make DESTDIR="$OUTPUT_DIR" install
