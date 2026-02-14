#!/bin/sh
set -ex

tar xfo libpsl-0.21.5.tar.gz
cd libpsl-0.21.5

mkdir build
cd    build

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

meson setup --prefix=/usr --buildtype=release

ninja
# TODO
# ninja test
DESTDIR=$OUTPUT_DIR ninja install
