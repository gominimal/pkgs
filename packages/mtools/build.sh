#!/bin/sh
set -e

tar -xof "mtools-${MINIMAL_ARG_VERSION}.tar.gz"
cd "mtools-${MINIMAL_ARG_VERSION}"

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

# --disable-floppyd / --without-x: floppyd is the only X11-dependent component;
# disabling it keeps the dependency set to glibc only (iconv is built into glibc).
./configure --prefix=/usr \
            --disable-floppyd \
            --without-x

make -j"$(nproc)"
make DESTDIR="$OUTPUT_DIR" install
