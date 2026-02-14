#!/bin/sh
set -e

sed -i 's/sighandler interrupt_signal/__sighandler_t interrupt_signal/' src/time.c

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

./configure --prefix=/usr

make -j$(nproc)

make DESTDIR=$OUTPUT_DIR install
