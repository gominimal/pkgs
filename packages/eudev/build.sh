#!/bin/bash
set -euo pipefail

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe"

./configure \
  --prefix=/usr \
  --disable-programs \
  --disable-manpages \
  --disable-hwdb

make -j$(nproc)
make DESTDIR=$OUTPUT_DIR install
