#!/bin/sh
set -e

tar xfo "bc-${MINIMAL_ARG_VERSION}.tar.xz"
cd "bc-${MINIMAL_ARG_VERSION}"

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

CC="gcc -std=c99" ./configure --prefix=/usr --disable-generated-tests --enable-readline

make -j$(nproc)
make test
make DESTDIR=$OUTPUT_DIR install
