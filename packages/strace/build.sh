#!/bin/sh
set -e

tar -xof strace-6.17.tar.xz
cd strace-6.17

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

./configure --prefix=/usr --enable-mpers=check
make -j$(nproc)

make DESTDIR="$OUTPUT_DIR" install
