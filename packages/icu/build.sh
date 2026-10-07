#!/bin/sh
set -e

tar -xof "icu4c-${MINIMAL_ARG_VERSION}-sources.tgz"
# The sources tarball carries the data prebuilt (data/in/icudt*.dat). Swap in ICU's text data sources, which
# the tools built here compile into a byte-identical archive.
find icu/source/data -delete
( cd icu/source && unzip -q "../../icu4c-${MINIMAL_ARG_VERSION}-data.zip" )
if ls icu/source/data/in/*.dat > /dev/null 2>&1; then
  echo "ERROR: prebuilt ICU data archive present after the swap" >&2
  exit 1
fi
cd icu/source

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

./configure --prefix=/usr

make -j$(nproc)
make DESTDIR=$OUTPUT_DIR install
