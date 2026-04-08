#!/bin/sh
set -e

mkdir -v build
cd build

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

../bootstrap --prefix=/usr --parallel=$(nproc) \
  --system-curl \
  --system-zlib \
  --system-bzip2 \
  --system-liblzma \
  --system-zstd \
  --system-expat \
  --system-libuv

make -j$(nproc)
make DESTDIR=$OUTPUT_DIR install
