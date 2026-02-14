#!/bin/sh
set -e

tar xfo "elfutils-${MINIMAL_ARG_VERSION}.tar.bz2"
cd "elfutils-${MINIMAL_ARG_VERSION}"

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

./configure --prefix=/usr                \
            --disable-debuginfod         \
            --enable-libdebuginfod=dummy

make -j$(nproc)

make DESTDIR="$OUTPUT_DIR" install
