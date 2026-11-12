#!/bin/sh
set -e
: "${MINIMAL_ARG_VERSION:?build_args must include version}"

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
            --docdir="/usr/share/doc/pkgconf-${MINIMAL_ARG_VERSION}"

make -j$(nproc)
make DESTDIR=$OUTPUT_DIR install

ln -sv pkgconf $OUTPUT_DIR/usr/bin/pkg-config
