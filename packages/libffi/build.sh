#!/bin/sh
set -e

tar xfo libffi-3.5.2.tar.gz
cd libffi-3.5.2

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

./configure  --prefix=/usr      \
            --libdir=/usr/lib   \
            --disable-static    \
            --with-gcc-arch=native

make -j$(nproc)
make check
make DESTDIR=$OUTPUT_DIR install
