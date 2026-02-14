#!/bin/sh
set -ex

tar xfo mpc-1.3.1.tar.gz
cd mpc-1.3.1

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

./configure  --prefix=/usr      \
            --disable-static    \
            --docdir=/usr/share/doc/mpc-1.3.1

make -j$(nproc)
#make check
make DESTDIR=$OUTPUT_DIR install
