#!/bin/sh
set -e
: "${MINIMAL_ARG_VERSION:?build_args must include version}"

tar -xof "bzip2-${MINIMAL_ARG_VERSION}.tar.gz"
cd "bzip2-${MINIMAL_ARG_VERSION}"

# Security backports from sourceware bzip2 master (see build.ncl). Applied
# before any compilation; `set -e` plus patch's non-zero exit on a rejected
# hunk aborts the build instead of shipping an unpatched bzip2recover, and -F0
# refuses fuzzy hunks so context drift on a bump fails rather than landing the
# change elsewhere. The patches live one level up because we cd'd into the
# extracted tree.
patch -Np1 -F0 -i ../0001-bzip2recover-CVE-2026-42250-max-handled-blocks.patch
patch -Np1 -F0 -i ../0002-bzip2recover-block-bounds-underflow.patch
patch -Np1 -F0 -i ../0003-bzip2recover-output-O_EXCL.patch

sed -i 's@\(ln -s -f \)$(PREFIX)/bin/@\1@' Makefile
sed -i "s@(PREFIX)/man@(PREFIX)/share/man@g" Makefile

make -f Makefile-libbz2_so
make clean

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O3 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"
export ARFLAGS=Drc

# bzip2 Makefile hardcodes '$(AR) cq' — replace with '$(AR) Drc'
sed -i 's/$(AR) cq/$(AR) Drc/' Makefile

make -j$(nproc)
make PREFIX="$OUTPUT_DIR/usr" install

cp -av libbz2.so.* "$OUTPUT_DIR/usr/lib/"
ln -sv "libbz2.so.${MINIMAL_ARG_VERSION}" "$OUTPUT_DIR/usr/lib/libbz2.so"

cp -v bzip2-shared "$OUTPUT_DIR/usr/bin/bzip2"
for i in "$OUTPUT_DIR/usr/bin/"{bzcat,bunzip2}; do
  ln -sfv bzip2 $i
done
