#!/bin/sh
set -ex

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

./configure  --prefix=/usr      \
            --disable-static    \
            --with-openssl      \
            --with-ca-path=/etc/ssl/certs

make -j$(nproc)
DESTDIR=$OUTPUT_DIR make install
