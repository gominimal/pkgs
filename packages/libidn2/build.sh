#!/bin/sh
set -e

tar xfo libidn2-2.3.8.tar.gz
cd libidn2-2.3.8

export CFLAGS="-march=x86-64-v3 -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

./configure --prefix=/usr --disable-static

make -j$(nproc)
make DESTDIR="$OUTPUT_DIR" install
