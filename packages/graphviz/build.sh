#!/bin/sh
set -e

sed '/ORIGIN/d' -i lib/CMakeLists.txt

mkdir build && cd build

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

cmake \
    -D CMAKE_INSTALL_PREFIX=/usr        \
    -D CMAKE_INSTALL_LIBDIR=/usr/lib    \
    -D CMAKE_BUILD_TYPE=Release         \
    ..

sed -i '/GZIP/s/:.*$/=/' CMakeCache.txt

make -j$(nproc)

LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:${OUTPUT_DIR}/usr/lib" DESTDIR=$OUTPUT_DIR make install
