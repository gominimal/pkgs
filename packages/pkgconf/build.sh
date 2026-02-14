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
            --docdir="/usr/share/doc/pkgconf-2.5.1"

make -j$(nproc)
make DESTDIR=$OUTPUT_DIR install

ln -sv pkgconf $OUTPUT_DIR/usr/bin/pkg-config
