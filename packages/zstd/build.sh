#!/bin/sh
set -ex

# /usr/bin/cc does not exist in the build environment
export CC=gcc
case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O3 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

# zstd 1.6.0 casts to LZ4F_contentChecksum_t itself (lz4 1.11.0 dropped the
# unprefixed name), so the 1.5.7 sed rewrite of programs/fileio.c is gone.

make -j$(nproc) prefix=/usr
# make check
make prefix=/usr DESTDIR=$OUTPUT_DIR install
