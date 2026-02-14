#!/bin/sh
set -e

cd CPP

mkdir build &&
cd    build

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

cmake -D CMAKE_INSTALL_PREFIX=/usr          \
      -D CMAKE_INSTALL_LIBDIR=/usr/lib      \
      -D CMAKE_BUILD_TYPE=Release           \
      -D CLIPPER2_EXAMPLES=OFF              \
      -D CLIPPER2_TESTS=OFF                 \
      -D BUILD_SHARED_LIBS=ON               \
      -G Ninja ..

ninja

DESTDIR="$OUTPUT_DIR" ninja install
