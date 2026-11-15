#!/bin/sh
set -ex

# /usr/bin/cc does not exist in the build environment
export CC=gcc
case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O3 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

# lz4 1.11.0 removed the unprefixed lz4frame names (LZ4F_ENABLE_OBSOLETE_ENUMS
# is gone), and zstd 1.5.7's programs/fileio.c still casts to the old
# `contentChecksum_t` (so does zstd dev at 49bf1d1). LZ4F_contentChecksum_t
# has existed since lz4 1.7, so the prefixed name works with every lz4 we
# could build against. The rewrite is a no-op once upstream renames it, and
# the check after it fails the build if any unprefixed use is left.
sed -i 's/(contentChecksum_t)/(LZ4F_contentChecksum_t)/' programs/fileio.c
if grep -nw contentChecksum_t programs/fileio.c; then
  echo "zstd: unprefixed lz4frame name left in programs/fileio.c" >&2
  exit 1
fi

make -j$(nproc) prefix=/usr
# make check
make prefix=/usr DESTDIR=$OUTPUT_DIR install
