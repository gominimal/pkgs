#!/bin/sh
set -ex

tar -xf patch-2.8.tar.xz
cd patch-2.8

export CFLAGS="-march=x86-64-v3 -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

./configure --prefix=/usr

make
make check
make DESTDIR="$OUTPUT_DIR" install
