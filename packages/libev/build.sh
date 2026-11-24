#!/bin/bash
set -euo pipefail

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export ARFLAGS=Drc

# Extraction does not keep the tarball's mtimes; equal mtimes keep make from trying to
# regenerate configure / Makefile.in with automake, which this build does not have.
find . -exec touch -d '2001-01-01 00:00:00' {} +

./configure \
  --prefix=/usr \
  --libdir=/usr/lib \
  --mandir=/usr/share/man \
  --enable-shared \
  --disable-static

make -j"$(nproc)"
make DESTDIR="$OUTPUT_DIR" install

rm -f "$OUTPUT_DIR"/usr/lib/*.la
# event.h is libev's libevent-emulation header. It has the same path as libevent's own
# event.h, so shipping it would make the two packages collide in one closure (Debian
# and Fedora drop it for the same reason). The emulation symbols stay in libev.so.
rm -f "$OUTPUT_DIR/usr/include/event.h"
