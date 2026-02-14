#!/bin/sh
set -e

tar xf make-4.4.1.tar.gz
cd make-4.4.1

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

./configure --prefix=/usr

make
# TODO "Error running /tmp/build-sandbox-1825609-0/make-4.4.1/tests/../make (expected 512; got 0)"
# make check
make DESTDIR=$OUTPUT_DIR install
