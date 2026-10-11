#!/bin/sh
set -e

tar -xof "libidn-$MINIMAL_ARG_VERSION.tar.gz"
cd "libidn-$MINIMAL_ARG_VERSION"

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"

./configure --prefix=/usr --disable-static --disable-java --disable-csharp --disable-doc

make -j$(nproc)
make DESTDIR="$OUTPUT_DIR" install
rm -f "$OUTPUT_DIR"/usr/lib/*.la
