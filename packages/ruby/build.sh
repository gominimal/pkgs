#!/bin/bash
set -euo pipefail

tar -xof ruby-4.0.1.tar.gz
cd ruby-4.0.1

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O3 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

./configure --prefix=/usr \
  --enable-shared \
  --disable-install-doc \
  --disable-install-rdoc

make -j$(nproc)
make DESTDIR=$OUTPUT_DIR install
