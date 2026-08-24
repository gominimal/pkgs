#!/bin/sh
set -ex

tar -xof libarchive-3.8.9.tar.gz
cd libarchive-3.8.9

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

# Library only — the bsd* tools aren't the point (diffoscope needs
# libarchive.so via python's libarchive-c) and every compressor we skip is a
# runtime dep we don't drag in. zlib/bzip2/zstd are the pkgs we already have.
./configure --prefix=/usr \
  --disable-bsdtar --disable-bsdcat --disable-bsdcpio --disable-bsdunzip \
  --with-zlib --with-bz2lib --with-zstd \
  --without-lz4 --without-lzo2 --without-lzma \
  --without-xml2 --without-expat \
  --without-openssl --without-nettle \
  --disable-acl --disable-xattr

make -j"$(nproc)"
# NOTE: no `make check` — libarchive's suite wants ACL/xattr/locale support
# we deliberately configured out; failures there wouldn't indict the library.
make DESTDIR="$OUTPUT_DIR" install
