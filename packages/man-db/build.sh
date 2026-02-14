#!/bin/sh
set -ex

tar xf man-db-2.13.1.tar.xz
cd man-db-2.13.1

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

./configure  --prefix=/usr     \
             --disable-setuid # gets around lack of useradd, but man page cache not updated by users using man

make -j$(nproc)
DESTDIR=$OUTPUT_DIR make install
