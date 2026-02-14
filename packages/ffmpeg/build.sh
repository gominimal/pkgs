#!/bin/sh
set -ex

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

./configure --prefix=/usr           \
            --disable-static        \
            --enable-shared         \
            --enable-gpl            \
            --enable-version3      \
            --enable-openssl        \
            --enable-libfreetype    \
            --enable-libfontconfig  \
            --disable-doc           \
            --disable-debug         \
            --disable-x86asm

make -j$(nproc)
make DESTDIR=$OUTPUT_DIR install
