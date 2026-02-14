#!/bin/sh
set -e

tar xfo gdbm-1.26.tar.gz
cd gdbm-1.26

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

./configure --prefix=/usr \
            --disable-static \
            --enable-libgdbm-compat

make -j$(nproc)
#make check
make DESTDIR="$OUTPUT_DIR" install
