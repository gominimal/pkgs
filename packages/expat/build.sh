#!/bin/sh
set -e

export CFLAGS="-march=x86-64-v3 -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

./configure --prefix="/usr" \
            --disable-static \
            --docdir="/usr/share/doc/expat-2.7.1"

make -j$(nproc)
make check
make DESTDIR=$OUTPUT_DIR install
