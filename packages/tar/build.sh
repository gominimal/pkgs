#!/bin/sh
set -e

tar xfo tar-1.35.tar.xz
cd tar-1.35

export CFLAGS="-march=x86-64-v3 -O3 -pipe"
export CXXFLAGS="${CFLAGS}"

FORCE_UNSAFE_CONFIGURE=1 ./configure --prefix=/usr

make -j$(nproc)
# TODO "setfattr: dir/file1: Operation not permitted"
# make check
make DESTDIR=$OUTPUT_DIR install
