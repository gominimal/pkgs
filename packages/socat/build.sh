#!/bin/bash
set -euo pipefail

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="$CFLAGS"

# OpenSSL 4: ASN1_STRING accessors instead of struct fields (see build.ncl).
patch -Np1 -F0 -i ./0001-openssl-4-asn1-string-accessors.patch
grep -q 'ASN1_STRING_get0_data(pName->d.iPAddress)' xio-openssl.c

./configure --prefix=/usr

make -j$(nproc)
make DESTDIR="$OUTPUT_DIR" install
