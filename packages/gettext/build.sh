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
            --docdir=/usr/share/doc/gettext-0.26

make -j$(nproc)
# make check # TODO: Move somewhere else
make DESTDIR="$OUTPUT_DIR" install
chmod -v 0755 "$OUTPUT_DIR/usr/lib/preloadable_libintl.so"
