#!/bin/sh
set -e

export CFLAGS="-march=x86-64-v3 -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

./configure --prefix="/usr"
make -j$(nproc)
# make check
make DESTDIR=$OUTPUT_DIR install
