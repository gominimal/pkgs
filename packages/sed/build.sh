#!/bin/sh
set -e

tar xf sed-4.9.tar.xz
cd sed-4.9

export CFLAGS="-march=x86-64-v3 -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

./configure --prefix="/usr"

make -j$(nproc)
# TODO make check
make DESTDIR=$OUTPUT_DIR install
