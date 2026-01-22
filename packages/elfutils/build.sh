#!/bin/sh
set -e

tar xfo "elfutils-${MINIMAL_ARG_VERSION}.tar.bz2"
cd "elfutils-${MINIMAL_ARG_VERSION}"

export CFLAGS="-march=x86-64-v3 -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

./configure --prefix=/usr                \
            --disable-debuginfod         \
            --enable-libdebuginfod=dummy

make -j$(nproc)

make DESTDIR="$OUTPUT_DIR" install
