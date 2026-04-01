#!/bin/sh
set -e

mkdir build &&
cd    build

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export SOURCE_DATE_EPOCH=0
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

cmake -D CMAKE_INSTALL_PREFIX=/usr      \
      -D CMAKE_INSTALL_LIBDIR=/usr/lib  \
      -D CMAKE_BUILD_TYPE=Release       \
      -D CMAKE_SKIP_INSTALL_RPATH=ON    \
      -D BUILD_SHARED_LIBS=ON           \
      -D LIEF_EXAMPLES=OFF              \
      -D LIEF_TESTS=OFF                 \
      -D LIEF_PYTHON_API=OFF            \
      -G Ninja ..

ninja

DESTDIR="$OUTPUT_DIR" ninja install
