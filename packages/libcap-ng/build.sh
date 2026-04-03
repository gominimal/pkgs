#!/bin/sh
set -ex

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

# GitHub tarballs don't include a pre-generated configure script
# Create required automake files not included in the git archive
touch NEWS
autoreconf -fiv
./configure --prefix=/usr --disable-static --without-python --without-python3
make -j$(nproc)
make DESTDIR=$OUTPUT_DIR install
