#!/bin/bash
set -euo pipefail

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export ARFLAGS=Drc

# Extraction does not keep the tarball's mtimes; equal mtimes keep make from trying to
# regenerate configure / Makefile.in with automake, which this build does not have.
find . -exec touch -d '2001-01-01 00:00:00' {} +

# OpenSSL is for the optional RSA client authentication (--username, --rsa-*-key).
# SCTP is off explicitly: pkgs has no lksctp-tools, and an autodetected netinet/sctp.h
# would make the result depend on what else happens to be in the sandbox.
./configure \
  --prefix=/usr \
  --libdir=/usr/lib \
  --mandir=/usr/share/man \
  --enable-shared \
  --disable-static \
  --without-sctp \
  --with-openssl=/usr

make -j"$(nproc)"
make DESTDIR="$OUTPUT_DIR" install

rm -f "$OUTPUT_DIR"/usr/lib/*.la

# Fail closed if the OpenSSL probe fell through: the auth options would silently vanish.
readelf -d "$OUTPUT_DIR/usr/lib/libiperf.so" | grep -q 'NEEDED.*libcrypto\.so\.4'
