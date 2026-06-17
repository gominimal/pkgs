#!/bin/sh
set -e

tar -xof libarchive-3.8.7.tar.xz
cd libarchive-3.8.7

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

# Lean libarchive: zlib (deflate — the common zip method), bzip2, and lzma are
# auto-detected from the build deps and cover standard zip/tar archives. The
# heavy optional backends are disabled to keep the runtime dep set small; add
# one back here if a consumer needs that format.
./configure --prefix=/usr        \
            --disable-static     \
            --without-xml2       \
            --without-openssl    \
            --without-nettle     \
            --without-libb2      \
            --without-lz4        \
            --without-zstd       \
            --without-iconv

make -j$(nproc)
make DESTDIR="$OUTPUT_DIR" install
