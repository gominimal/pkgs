#!/bin/sh
set -e

tar xf lz4-1.10.0.tar.gz
cd lz4-1.10.0

export CC=gcc
case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O3 -pipe"
export CXXFLAGS="${CFLAGS}"

make -j$(nproc) BUILD_STATIC=no PREFIX=/usr
# make -j1 check
make BUILD_STATIC=no PREFIX=/usr DESTDIR=$OUTPUT_DIR install
