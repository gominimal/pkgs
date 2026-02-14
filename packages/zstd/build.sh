#!/bin/sh
set -ex

# /usr/bin/cc does not exist in the build environment
export CC=gcc
case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O3 -pipe"
export CXXFLAGS="${CFLAGS}"

make -j$(nproc) prefix=/usr
# make check
make prefix=/usr DESTDIR=$OUTPUT_DIR install
