#!/bin/sh
set -e

tar xfo strace-6.17.tar.xz
cd strace-6.17

export CFLAGS="-march=x86-64-v3 -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

./configure --prefix=/usr
make -j$(nproc)

make DESTDIR="$OUTPUT_DIR" install
