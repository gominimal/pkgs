#!/bin/sh
set -e

tar -xof vim-9.1.1629.tar.gz
cd vim-9.1.1629

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export SOURCE_DATE_EPOCH=0
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

./configure --prefix=/usr        \
            --with-features=huge \
            --enable-gui=no      \
            --without-x          \
            --with-tlib=ncursesw

make -j$(nproc)
make DESTDIR=$OUTPUT_DIR install
