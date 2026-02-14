#!/bin/sh
set -e

tar xf xz-5.8.1.tar.xz
cd xz-5.8.1

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

./configure --prefix=/usr   \
           --disable-static \
           --docdir=/usr/share/doc/xz-5.8.1

make -j$(nproc)
# make check
make DESTDIR="$OUTPUT_DIR" install
