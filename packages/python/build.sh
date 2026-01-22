#!/bin/sh
set -e

tar xf Python-3.13.7.tar.xz
cd Python-3.13.7

export CFLAGS="-march=x86-64-v3 -O3 -pipe"
export CXXFLAGS="${CFLAGS}"

./configure  --prefix=/usr          \
            --enable-shared         \
            --with-system-expat     \
            --enable-optimizations  \
            --without-static-libpython

make -j$(nproc)
# TODO
#make test TESTOPTS="--timeout 120"
make DESTDIR=$OUTPUT_DIR install
