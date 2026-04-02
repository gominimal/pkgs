#!/bin/sh
set -e

tar -xof boost-1.89.0-b2-nodocs.tar.xz
cd boost-1.89.0

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

./bootstrap.sh --prefix=/usr --with-python=python3
./b2 stage -j$(nproc) threading=multi link=shared

pushd tools/build/test; python3 test_all.py; popd

./b2 --prefix=$OUTPUT_DIR/usr install threading=multi link=shared
