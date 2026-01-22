#!/bin/sh
set -e

tar xf gzip-1.14.tar.xz
cd gzip-1.14

export CFLAGS="-march=x86-64-v3 -O3 -pipe"
export CXXFLAGS="${CFLAGS}"

./configure --prefix=/usr

make -j$(nproc)
make check
make DESTDIR=$OUTPUT_DIR install
