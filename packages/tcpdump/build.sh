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
# regenerate configure with autoconf, which this build does not have.
find . -exec touch -d '2001-01-01 00:00:00' {} +

# libpcap is found through pkg-config (libpcap.pc). libcrypto (ESP decryption, -E) and
# libcap-ng (dropping capabilities with -Z) are required, not "if available", so a
# missing one fails here instead of quietly building a tcpdump without them. libsmi
# (SNMP MIB names) is not packaged.
./configure \
  --prefix=/usr \
  --mandir=/usr/share/man \
  --with-crypto=yes \
  --with-cap-ng=yes \
  --without-smi

make -j"$(nproc)"
make DESTDIR="$OUTPUT_DIR" install

# make install also copies the binary to usr/bin/tcpdump.<version>.
rm -f "$OUTPUT_DIR/usr/bin/tcpdump.$MINIMAL_ARG_VERSION"

# Fail closed on the libraries tcpdump is meant to link: our libpcap, OpenSSL 4's
# libcrypto (never 3.x), and libcap-ng.
needed=$(readelf -d "$OUTPUT_DIR/usr/bin/tcpdump" | sed -n 's/.*Shared library: \[\(.*\)\]/\1/p')
echo "$needed"
for lib in libpcap.so.1 libcrypto.so.4 libcap-ng.so.0; do
  grep -qx "$lib" <<<"$needed" || { echo "ERROR: tcpdump does not NEED $lib" >&2; exit 1; }
done
if grep -q '^libcrypto\.so\.3$' <<<"$needed"; then
  echo "ERROR: tcpdump NEEDs OpenSSL 3's libcrypto.so.3" >&2
  exit 1
fi
