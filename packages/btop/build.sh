#!/bin/sh
set -e
cd btop-1.4.6

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

# Disable GPU paths at compile time
make -j"$(nproc)" GPU_SUPPORT=false
make DESTDIR="${OUTPUT_DIR}" PREFIX="/usr" install
