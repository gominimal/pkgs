#!/bin/sh
set -e

tar xfo libffi-3.5.2.tar.gz
cd libffi-3.5.2

export CFLAGS="-march=x86-64-v3 -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

./configure  --prefix=/usr      \
            --disable-static    \
            --with-gcc-arch=native

make -j$(nproc)
make check
make DESTDIR=$OUTPUT_DIR install
