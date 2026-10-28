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

./configure  --prefix=/usr      \
            --disable-static    \
            --with-openssl      \
            --with-nghttp2      \
            --with-ca-path=/etc/ssl/certs
# Fail closed if configure did not pick up nghttp2 (see build.ncl).
grep -q '^#define USE_NGHTTP2 1' lib/curl_config.h || {
  echo "ERROR: curl configured without HTTP/2 (nghttp2 not found)" >&2
  exit 1
}

make -j$(nproc)
DESTDIR=$OUTPUT_DIR make install
