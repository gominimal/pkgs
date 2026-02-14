#!/bin/sh
set -e

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

./config  --prefix=/usr         \
         --openssldir=/etc/ssl  \
         --libdir=lib           \
         shared                 \
         zlib-dynamic

make -j$(nproc)
# HARNESS_JOBS=$(nproc) make test
sed -i '/INSTALL_LIBS/s/libcrypto.a libssl.a//' Makefile
make DESTDIR="$OUTPUT_DIR" MANSUFFIX=ssl install
