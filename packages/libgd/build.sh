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
    -D BUILD_STATIC_LIBS=OFF \
    -D ENABLE_PNG=1 \
    -D ENABLE_JPEG=1 \
    -D ENABLE_FREETYPE=1 \
    -D ENABLE_FONTCONFIG=1 \
    -D ENABLE_GD_FORMATS=1 \
    -D ENABLE_WEBP=0 \
    -D ENABLE_TIFF=0 \
    -D ENABLE_HEIF=0 \
    -D ENABLE_AVIF=0 \
    -D ENABLE_XPM=0 \
    -D ENABLE_ICONV=0 \
    -D ENABLE_LIQ=0 \
    -D ENABLE_RAQM=0 \
    -D CMAKE_SKIP_INSTALL_RPATH=ON \
    ..

make -j$(nproc)
DESTDIR="$OUTPUT_DIR" make install
