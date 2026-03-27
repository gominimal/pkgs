#!/bin/sh
set -e

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

mkdir build && cd build
meson setup --prefix=/usr --buildtype=release \
  -Dx11=enabled \
  -Dglx=enabled \
  -Degl=true \
  -Dgles1=true \
  -Dgles2=true \
  -Dtls=true \
  -Dheaders=true \
  ..
ninja
DESTDIR="$OUTPUT_DIR" ninja install
