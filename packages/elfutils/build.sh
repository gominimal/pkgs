#!/bin/sh
set -e

tar xfo "elfutils-${MINIMAL_ARG_VERSION}.tar.bz2"
cd "elfutils-${MINIMAL_ARG_VERSION}"

./configure --prefix=/usr                \
            --disable-debuginfod         \
            --enable-libdebuginfod=dummy

make -j$(nproc)

make DESTDIR="$OUTPUT_DIR" install
