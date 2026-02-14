#!/bin/sh
set -e

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

./configure --prefix=/usr     \
            --sysconfdir=/etc \
            --enable-utf8     \
            --docdir=/usr/share/doc/nano-$MINIMAL_ARG_VERSION
make -j$(nproc)

make DESTDIR="$OUTPUT_DIR" install
install -v -m644 doc/{nano.html,sample.nanorc} "${OUTPUT_DIR}/usr/share/doc/nano-${MINIMAL_ARG_VERSION}"
