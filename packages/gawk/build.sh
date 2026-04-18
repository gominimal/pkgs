#!/bin/sh
set -e

tar -xof "gawk-$MINIMAL_ARG_VERSION.tar.xz"
cd "gawk-$MINIMAL_ARG_VERSION"

sed -i 's/extras//' Makefile.in

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

./configure --prefix=/usr

make -j$(nproc)
# TODO
# make check
make DESTDIR=$OUTPUT_DIR install

# gawkbug is a shell script to report bugs in gawk- not needed
rm "$OUTPUT_DIR/usr/bin/gawkbug"
