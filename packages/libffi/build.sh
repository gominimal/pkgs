#!/bin/sh
set -e

tar -xof libffi-3.5.2.tar.gz
cd libffi-3.5.2

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

./configure  --prefix=/usr      \
            --libdir=/usr/lib   \
            --disable-static    \
            --with-gcc-arch=native

make -j$(nproc)
make check
make DESTDIR=$OUTPUT_DIR install

# On aarch64, libtool may install to lib64 despite --libdir=/usr/lib.
# Merge lib64 into lib so output globs find the files.
if [ -d "$OUTPUT_DIR/usr/lib64" ]; then
    cp -a "$OUTPUT_DIR/usr/lib64/"* "$OUTPUT_DIR/usr/lib/" 2>/dev/null || true
    rm -rf "$OUTPUT_DIR/usr/lib64"
fi
