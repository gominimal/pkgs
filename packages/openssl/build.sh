#!/bin/sh
set -e

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
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

# 4.x layout, fail-closed: SHLIB_VERSION=4 (libssl.so.4 / libcrypto.so.4, every symbol
# versioned OPENSSL_4.0.0, so a libssl.so.3 from packages/openssl-3.5 can share a process),
# providers under lib/ossl-modules, and no engines or c_rehash (both removed in 4.0).
test -e "$OUTPUT_DIR/usr/lib/libssl.so.4"
test -e "$OUTPUT_DIR/usr/lib/libcrypto.so.4"
test -e "$OUTPUT_DIR/usr/lib/ossl-modules/legacy.so"
