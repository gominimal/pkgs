#!/bin/sh
set -ex

tar xfo gmp-6.3.0.tar.xz
cd gmp-6.3.0

sed -i '/long long t1;/,+1s/()/(...)/' configure

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

./configure  --prefix=/usr     \
            --enable-cxx     \
            --disable-static \
            --docdir=/usr/share/doc/gmp-6.3.0

make -j$(nproc)
make check
make DESTDIR=$OUTPUT_DIR install
