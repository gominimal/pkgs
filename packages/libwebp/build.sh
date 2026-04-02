#!/bin/sh
set -e

mkdir build && cd build

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

cmake \
    -D CMAKE_INSTALL_PREFIX=/usr \
    -D CMAKE_INSTALL_LIBDIR=/usr/lib \
    -D CMAKE_BUILD_TYPE=Release \
    -D BUILD_SHARED_LIBS=ON \
    -D WEBP_BUILD_CWEBP=ON \
    -D WEBP_BUILD_DWEBP=ON \
    -D WEBP_BUILD_GIF2WEBP=OFF \
    -D WEBP_BUILD_IMG2WEBP=OFF \
    -D WEBP_BUILD_ANIM_UTILS=OFF \
    -D WEBP_BUILD_EXTRAS=OFF \
    -D CMAKE_SKIP_INSTALL_RPATH=ON \
    ..

make -j$(nproc)
DESTDIR="$OUTPUT_DIR" make install
