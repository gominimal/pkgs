#!/bin/sh
set -e

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

./configure  --prefix=/usr      \
            --disable-static    \
            --sysconfdir=/etc   \
            --docdir=/usr/share/doc/attr-2.5.2

make -j$(nproc)
# make check # TODO
make DESTDIR="$OUTPUT_DIR" install
