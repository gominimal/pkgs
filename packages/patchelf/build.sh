#!/bin/sh
set -e

tar -xof b49de1b3384e7928bf0df9a889fe5a4e7b3fbddf.tar.gz
cd patchelf-b49de1b3384e7928bf0df9a889fe5a4e7b3fbddf

mkdir build
cd build

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export SOURCE_DATE_EPOCH=0
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

cmake .. -GNinja -DCMAKE_INSTALL_PREFIX=/usr
ninja all

DESTDIR=$OUTPUT_DIR ninja install
