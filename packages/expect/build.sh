#!/bin/sh
set -e

tar -xof expect5.45.4.tar.gz
cd expect5.45.4

patch -Np1 -i ../expect-5.45.4-gcc15-1.patch

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3"; BUILD_TRIPLET="x86_64-unknown-linux-gnu" ;;
  aarch64) MARCH="-march=armv8-a";   BUILD_TRIPLET="aarch64-unknown-linux-gnu" ;;
  *)       MARCH="";                 BUILD_TRIPLET="$(uname -m)-unknown-linux-gnu" ;;
esac
export SOURCE_DATE_EPOCH=0
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

./configure  --prefix=/usr            \
            --build="$BUILD_TRIPLET" \
            --host="$BUILD_TRIPLET"  \
            --with-tcl=/usr/lib     \
            --enable-shared         \
            --disable-rpath         \
            --mandir=/usr/share/man \
            --with-tclinclude=/usr/include

make -j$(nproc)
# make test # TODO has failures
make DESTDIR=$OUTPUT_DIR install
ln -svf expect5.45.4/libexpect5.45.4.so $OUTPUT_DIR/usr/lib
