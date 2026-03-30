#!/bin/sh
set -e

tar -xof tar-1.35.tar.xz
cd tar-1.35

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export SOURCE_DATE_EPOCH=0
export CFLAGS="$MARCH -O3 -pipe -gno-record-gcc-switches -Wl,--build-id=none -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

FORCE_UNSAFE_CONFIGURE=1 ./configure --prefix=/usr

make -j$(nproc)
# TODO "setfattr: dir/file1: Operation not permitted"
# make check
make DESTDIR=$OUTPUT_DIR install
