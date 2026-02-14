#!/bin/sh
set -ex

tar xf libpipeline-1.5.8.tar.gz
cd libpipeline-1.5.8

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

./configure  --prefix=/usr     \
             --disable-static

make -j$(nproc)
make DESTDIR="$OUTPUT_DIR" install
