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

mkdir _build && cd _build

../configure \
  --prefix=/usr \
  --enable-shared \
  --disable-static \
  --enable-vp8 \
  --enable-vp9 \
  --enable-pic \
  --enable-postproc \
  --enable-vp9-postproc \
  --enable-vp9-highbitdepth \
  --disable-install-docs \
  --disable-install-srcs \
  --disable-unit-tests \
  --as=nasm

make -j$(nproc)
make DESTDIR="$OUTPUT_DIR" install
