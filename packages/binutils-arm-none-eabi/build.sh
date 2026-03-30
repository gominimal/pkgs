#!/bin/sh
set -e

tar -xof "binutils-${MINIMAL_ARG_VERSION}.tar.xz"
cd "binutils-${MINIMAL_ARG_VERSION}"

mkdir -v build
cd build

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export SOURCE_DATE_EPOCH=0
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

../configure \
    --prefix=/usr \
    --target=arm-none-eabi \
    --with-sysroot=/usr/arm-none-eabi \
    --enable-multilib \
    --enable-interwork \
    --enable-plugins \
    --enable-deterministic-archives \
    --disable-nls \
    --disable-werror

# Avoid requiring texinfo for building docs
make MAKEINFO=true -j$(nproc)
make MAKEINFO=true DESTDIR=$OUTPUT_DIR install-strip

# Remove info pages that conflict with host binutils
rm -rf "$OUTPUT_DIR/usr/share/info"
# Remove lib files only relevant to host binutils
rm -f "$OUTPUT_DIR/usr/lib/bfd-plugins/libdep.so"
rm -rf "$OUTPUT_DIR/usr/lib/bfd-plugins" 2>/dev/null || true
