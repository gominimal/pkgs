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

# GOST needs an OpenSSL ENGINE, which OpenSSL 4 removed. No rpath: the library lives in
# /usr/lib already. --sysconfdir=/etc makes the compiled-in default trust anchor
# /etc/unbound/root.key rather than /usr/etc/unbound/root.key.
./configure \
  --prefix=/usr \
  --libdir=/usr/lib \
  --mandir=/usr/share/man \
  --sysconfdir=/etc \
  --with-ssl=/usr \
  --enable-shared \
  --disable-static \
  --disable-rpath \
  --disable-gost \
  --without-drill \
  --without-examples \
  --without-pyldns \
  --without-pyldnsx \
  --without-p5-dns-ldns

make -j"$(nproc)"
make DESTDIR="$OUTPUT_DIR" install

# Library, headers and pkg-config only: no libtool archive, no ldns-config script, no
# manpages (outputs).
rm -f "$OUTPUT_DIR"/usr/lib/*.la "$OUTPUT_DIR/usr/bin/ldns-config"
rm -rf "$OUTPUT_DIR/usr/share/man"
