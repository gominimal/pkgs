#!/bin/sh
set -e

tar xf sed-4.9.tar.xz
cd sed-4.9

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

./configure --prefix="/usr"

make -j$(nproc)
# TODO make check
make DESTDIR=$OUTPUT_DIR install
