#!/bin/sh
set -ex

tar xfo zlib-1.3.1.tar.gz
cd zlib-1.3.1

export CFLAGS="-march=x86-64-v3 -O3 -pipe"
export CXXFLAGS="${CFLAGS}"

./configure --prefix=/usr

make -j$(nproc)
make check
make DESTDIR=$OUTPUT_DIR install
