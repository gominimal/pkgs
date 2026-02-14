#!/bin/sh
set -ex

tar xfo mpfr-4.2.2.tar.xz
cd mpfr-4.2.2

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

./configure  --prefix=/usr          \
            --disable-static        \
            --enable-thread-safe    \
            --docdir=/usr/share/doc/mpfr-4.2.2

make -j$(nproc)
#make check
make DESTDIR=$OUTPUT_DIR install
