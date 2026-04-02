#!/bin/sh
set -e

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

mkdir build && cd build
meson setup --prefix=/usr --buildtype=release \
  -Dsystemd=disabled \
  -Dapparmor=disabled \
  -Dselinux=disabled \
  -Dlaunchd=disabled \
  -Dx11_autolaunch=disabled \
  -Dxml_docs=disabled \
  -Ddoxygen_docs=disabled \
  -Dmodular_tests=disabled \
  ..
ninja
DESTDIR="$OUTPUT_DIR" ninja install
