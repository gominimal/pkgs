#!/bin/sh
set -ex

export CFLAGS="-march=x86-64-v3 -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

./configure --prefix=/usr           \
            --disable-static        \
            --enable-shared         \
            --enable-gpl            \
            --enable-version3      \
            --enable-openssl        \
            --enable-libfreetype    \
            --enable-libfontconfig  \
            --disable-doc           \
            --disable-debug         \
            --disable-x86asm

make -j$(nproc)
make DESTDIR=$OUTPUT_DIR install
