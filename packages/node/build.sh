#!/bin/sh
set -e

export CC=gcc

tar xfo "node-v${MINIMAL_ARG_VERSION}.tar.xz"
cd "node-v${MINIMAL_ARG_VERSION}"

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

./configure --prefix=/usr --with-intl=system-icu --shared-openssl --shared-zlib --shared-sqlite --shared-libuv

make -j$(nproc)
make DESTDIR=$OUTPUT_DIR install
