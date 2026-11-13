#!/bin/bash
set -euo pipefail

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"

# Extraction does not keep the tarball's mtimes, so configure.ac can look newer than configure
# and make reruns autoconf and automake, which this build does not have. Equal mtimes: nothing is stale.
find . -exec touch -d '2001-01-01 00:00:00' {} +

./configure --prefix=/usr --libdir=/usr/lib --disable-static
make -j$(nproc)
make DESTDIR="$OUTPUT_DIR" install
rm -f "$OUTPUT_DIR"/usr/lib/*.la
