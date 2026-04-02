#!/bin/sh
set -ex

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"

./configure --prefix=/usr \
            --disable-static \
            --enable-shared \
            --disable-asm

make -j$(nproc)
make DESTDIR=$OUTPUT_DIR install
