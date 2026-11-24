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

# Linux capture only (packet sockets + usbmon). Everything optional that would pull in
# another library is off explicitly, so the result does not depend on what else happens
# to be in the sandbox: libnl (802.11 monitor mode via nl80211), D-Bus, RDMA, Bluetooth,
# remote capture (rpcapd).
./configure \
  --prefix=/usr \
  --libdir=/usr/lib \
  --mandir=/usr/share/man \
  --enable-shared \
  --without-libnl \
  --disable-dbus \
  --disable-rdma \
  --disable-bluetooth \
  --disable-remote

make -j"$(nproc)"
make DESTDIR="$OUTPUT_DIR" install

# Shared library only: the install always copies libpcap.a as well.
rm -f "$OUTPUT_DIR/usr/lib/libpcap.a"
