#!/bin/bash
set -euo pipefail

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"

test -s debian/patches/series
while IFS= read -r p; do
  case "$p" in ''|'#'*) continue ;; esac
  patch -Np1 -F0 -i "debian/patches/$p"
done < debian/patches/series

make -j$(nproc) CC=gcc \
  CFLAGS="$CFLAGS -DDEBIAN_VERSION=\\\"$MINIMAL_ARG_VERSION-$MINIMAL_ARG_DEBIAN_REVISION\\\"" \
  LDFLAGS="-Wl,--build-id=none"

install -Dm755 nc "$OUTPUT_DIR/usr/bin/nc"
ln -s nc "$OUTPUT_DIR/usr/bin/netcat"
install -Dm644 nc.1 "$OUTPUT_DIR/usr/share/man/man1/nc.1"
