#!/bin/sh
set -e

tar xfo flex-2.6.4.tar.gz
cd flex-2.6.4

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

./configure  --prefix=/usr \
            --docdir=/usr/share/doc/flex-2.6.4 \
            --disable-static

make -j$(nproc)
make check
make DESTDIR=$OUTPUT_DIR install
