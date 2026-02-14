#!/bin/sh
set -e

mkdir -v build
cd       build

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

cmake -D CMAKE_BUILD_TYPE=Release       \
      -D CMAKE_INSTALL_PREFIX=/usr      \
      -D CMAKE_INSTALL_LIBDIR=/usr/lib  \
      -D BUILD_STATIC_LIBS=OFF ..

make -j$(nproc)
make DESTDIR="$OUTPUT_DIR" install
