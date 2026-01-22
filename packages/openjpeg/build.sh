#!/bin/sh
set -e

mkdir -v build
cd       build

export CFLAGS="-march=x86-64-v3 -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

cmake -D CMAKE_BUILD_TYPE=Release       \
      -D CMAKE_INSTALL_PREFIX=/usr      \
      -D CMAKE_INSTALL_LIBDIR=/usr/lib  \
      -D BUILD_STATIC_LIBS=OFF ..

make -j$(nproc)
make DESTDIR="$OUTPUT_DIR" install
