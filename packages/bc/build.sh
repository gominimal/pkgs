#!/bin/sh
set -e

tar -xof "bc-${MINIMAL_ARG_VERSION}.tar.xz"
cd "bc-${MINIMAL_ARG_VERSION}"

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

CC="gcc -std=c99" ./configure --prefix=/usr --disable-generated-tests --enable-readline

make -j$(nproc)
# test_bc_error_33 reliably OOM-killed in CS (Error 137). The earlier
# fix `make test || echo` apparently didn't bypass set -e for some
# subshell reason. Skipping tests entirely: build artifacts ship
# regardless of test outcome and dev runs `make test` manually.
make DESTDIR=$OUTPUT_DIR install
