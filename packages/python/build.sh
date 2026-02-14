#!/bin/sh
set -e

tar xf Python-3.13.7.tar.xz
cd Python-3.13.7

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O3 -pipe"
export CXXFLAGS="${CFLAGS}"

./configure  --prefix=/usr          \
            --enable-shared         \
            --with-system-expat     \
            --enable-optimizations  \
            --without-static-libpython

make -j$(nproc)
# TODO
#make test TESTOPTS="--timeout 120"
make DESTDIR=$OUTPUT_DIR install
