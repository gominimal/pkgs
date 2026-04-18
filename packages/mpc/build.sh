#!/bin/sh
set -ex

tar -xof "mpc-$MINIMAL_ARG_VERSION.tar.xz"
cd "mpc-$MINIMAL_ARG_VERSION"

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

./configure  --prefix=/usr      \
            --disable-static    \
            --docdir="/usr/share/doc/mpc-$MINIMAL_ARG_VERSION"

make -j$(nproc)
#make check
make DESTDIR=$OUTPUT_DIR install
