#!/bin/sh
set -e

tar -xof "e2fsprogs-${MINIMAL_ARG_VERSION}.tar.xz"
cd "e2fsprogs-${MINIMAL_ARG_VERSION}"

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

./configure --bindir=/usr/bin       \
            --sbindir=/usr/sbin     \
            --libdir=/usr/lib       \
            --enable-elf-shlibs     \
            --disable-defrag        \
            --without-libintl-prefix

make -j$(nproc)
make DESTDIR=$OUTPUT_DIR install
