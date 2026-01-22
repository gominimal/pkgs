#!/bin/sh
set -e

tar -xf bison-3.8.2.tar.xz
cd bison-3.8.2

export CFLAGS="-march=x86-64-v3 -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

./configure --prefix=/usr --docdir=/usr/share/doc/bison-3.8.2

make -j$(nproc)
# make check # TODO
make DESTDIR=$OUTPUT_DIR install
