#!/bin/sh
set -e

sed '/ORIGIN/d' -i lib/CMakeLists.txt

mkdir build && cd build

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export SOURCE_DATE_EPOCH=0
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

cmake \
    -D CMAKE_INSTALL_PREFIX=/usr        \
    -D CMAKE_INSTALL_LIBDIR=/usr/lib    \
    -D CMAKE_BUILD_TYPE=Release         \
    -D WITH_ZLIB=ON                     \
    -D WITH_SMYRNA=OFF                  \
    -D WITH_GVEDIT=OFF                  \
    -D WITH_X=OFF                       \
    ..

sed -i '/GZIP/s/:.*$/=/' CMakeCache.txt

make -j$(nproc)

LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:${OUTPUT_DIR}/usr/lib" DESTDIR=$OUTPUT_DIR make install

