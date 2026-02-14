#!/bin/sh
set -e

cd "binutils-${MINIMAL_ARG_VERSION}"

mkdir -v build
cd build

# TODO
# --enable-nls

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O3 -pipe"
export CXXFLAGS="${CFLAGS}"

../configure    --prefix=/usr       \
                --sysconfdir=/etc   \
                --enable-ld=default \
                --enable-plugins    \
                --enable-shared     \
                --disable-werror    \
                --disable-nls       \
                --enable-new-dtags  \
                --with-system-zlib  \
                --enable-default-hash-style=gnu

make -j$(nproc) tooldir=/usr
# make -k check # TODO
make tooldir=/usr DESTDIR=$OUTPUT_DIR install-strip
