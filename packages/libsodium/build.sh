#!/bin/sh
set -ex

export CFLAGS="-march=x86-64-v3 -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

autoreconf -fi
./configure --prefix=/usr --disable-static
make -j$(nproc)
make DESTDIR=$OUTPUT_DIR install
