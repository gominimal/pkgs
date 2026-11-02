#!/bin/sh
set -ex

# $MINIMAL_ARG_VERSION is forwarded from build.ncl's `version` via build_args.
tar -xof "patch-${MINIMAL_ARG_VERSION}.tar.xz"
cd "patch-${MINIMAL_ARG_VERSION}"

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

./configure --prefix=/usr

make
make check
make DESTDIR="$OUTPUT_DIR" install
