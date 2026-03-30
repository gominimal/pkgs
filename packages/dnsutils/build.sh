#!/bin/sh
set -ex

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export SOURCE_DATE_EPOCH=0
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

tar --no-same-owner -xf bind-${MINIMAL_ARG_VERSION}.tar.xz
cd bind-${MINIMAL_ARG_VERSION}

./configure --prefix=/usr       \
  --disable-static              \
  --with-openssl                \
  --without-lmdb                \
  --disable-geoip               \
  --without-json-c              \
  --without-libxml2             \
  --disable-doh

make -j$(nproc)

# Install everything, then keep only client binaries.
# Output globs in build.ncl select only dig/host/nslookup/nsupdate.
DESTDIR=$OUTPUT_DIR make install
