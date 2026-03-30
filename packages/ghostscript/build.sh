#!/bin/sh
set -e

# Remove source trees for libraries which are bundled but we build separately
rm -rf freetype lcms2mt jpeg libpng openjpeg

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export SOURCE_DATE_EPOCH=0
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

./configure --prefix=/usr \
            --disable-static \
            --with-system-libtiff \
            --disable-compiler-inits \
            CFLAGS="${CFLAGS:--g -O3} -fPIC"

make -j$(nproc)

make DESTDIR="$OUTPUT_DIR" install
