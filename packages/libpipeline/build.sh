#!/bin/sh
set -ex

tar xf libpipeline-1.5.8.tar.gz
cd libpipeline-1.5.8

export CFLAGS="-march=x86-64-v3 -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

./configure  --prefix=/usr     \
             --disable-static

make -j$(nproc)
make DESTDIR="$OUTPUT_DIR" install
