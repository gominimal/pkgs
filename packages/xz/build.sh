#!/bin/sh
set -e

tar -xof xz-5.8.1.tar.xz
cd xz-5.8.1

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export SOURCE_DATE_EPOCH=0
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

./configure --prefix=/usr   \
           --disable-static \
           --docdir=/usr/share/doc/xz-5.8.1

make -j$(nproc)
# make check
make DESTDIR="$OUTPUT_DIR" install
