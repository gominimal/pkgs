#!/bin/sh
set -e

# Security backports — CVEs fixed upstream after the 1.25.0 release (see
# build.ncl for provenance). `set -e` plus patch's non-zero exit on a rejected
# hunk means a stale patch ABORTS the build rather than silently shipping an
# unpatched wget. Each touches a different src/ file, so order is immaterial.
patch -Np1 -i "CVE-2026-58469.patch"   # metalink.c  clean_metalink_string buffer underflow
patch -Np1 -i "CVE-2026-58470.patch"   # http.c      parse_content_range integer overflow
patch -Np1 -i "CVE-2026-58471.patch"   # url.c       filename-conversion buffer size
patch -Np1 -i "CVE-2026-58472.patch"   # convert.c   html_quote_string integer+buffer overflow

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

./configure --prefix=/usr      \
            --sysconfdir=/etc  \
            --with-ssl=openssl
make -j$(nproc)

make DESTDIR="$OUTPUT_DIR" install
