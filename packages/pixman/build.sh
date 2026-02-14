#!/bin/sh
set -e

mkdir build &&
cd    build &&

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe"
export CXXFLAGS="${CFLAGS}"
meson setup --prefix=/usr --buildtype=release ..
ninja

DESTDIR="$OUTPUT_DIR" ninja install
