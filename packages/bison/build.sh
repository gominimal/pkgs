#!/bin/sh
set -e

tar -xf bison-3.8.2.tar.xz
cd bison-3.8.2

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

./configure --prefix=/usr --docdir=/usr/share/doc/bison-3.8.2

make -j$(nproc)
# make check # TODO
make DESTDIR=$OUTPUT_DIR install
