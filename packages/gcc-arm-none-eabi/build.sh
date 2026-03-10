#!/bin/sh
set -e

TARGET=arm-none-eabi
PREFIX="/usr"

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe"
export CXXFLAGS="${CFLAGS}"
export CFLAGS_FOR_TARGET="-g -O2 -ffunction-sections -fdata-sections"
export CXXFLAGS_FOR_TARGET="-g -O2 -ffunction-sections -fdata-sections"

# Extract sources
tar -xof "gcc-${MINIMAL_ARG_GCC_VERSION}.tar.xz"
tar -xof "newlib-${MINIMAL_ARG_NEWLIB_VERSION}.tar.gz"

# Symlink newlib into GCC source tree for unified in-tree build
ln -s "../newlib-${MINIMAL_ARG_NEWLIB_VERSION}/newlib" "gcc-${MINIMAL_ARG_GCC_VERSION}/newlib"
ln -s "../newlib-${MINIMAL_ARG_NEWLIB_VERSION}/libgloss" "gcc-${MINIMAL_ARG_GCC_VERSION}/libgloss"

# Build GCC + newlib together in a single pass
mkdir -p build
cd build

"../gcc-${MINIMAL_ARG_GCC_VERSION}/configure" \
    --prefix="$PREFIX" \
    --target=$TARGET \
    --with-newlib \
    --enable-languages=c,c++ \
    --enable-multilib \
    --with-multilib-list=rmprofile \
    --enable-newlib-io-long-long \
    --enable-newlib-io-c99-formats \
    --enable-newlib-register-fini \
    --enable-newlib-retargetable-locking \
    --disable-newlib-supplied-syscalls \
    --disable-shared \
    --disable-threads \
    --disable-tls \
    --disable-nls \
    --disable-libssp \
    --disable-libgomp \
    --disable-libquadmath \
    --with-system-zlib \
    --with-gmp=/usr \
    --with-mpfr=/usr \
    --with-mpc=/usr

make MAKEINFO=true -j$(nproc)
make MAKEINFO=true DESTDIR="$OUTPUT_DIR" install-strip

cd ..

# Remove info/man pages that conflict with host gcc
rm -rf "$OUTPUT_DIR$PREFIX/share/info"
