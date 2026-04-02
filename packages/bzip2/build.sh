#!/bin/sh
set -e

tar -xof bzip2-1.0.8.tar.gz
cd bzip2-1.0.8

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
ln -sv libbz2.so.1.0.8 "$OUTPUT_DIR/usr/lib/libbz2.so"

cp -v bzip2-shared "$OUTPUT_DIR/usr/bin/bzip2"
for i in "$OUTPUT_DIR/usr/bin/"{bzcat,bunzip2}; do
  ln -sfv bzip2 $i
done
