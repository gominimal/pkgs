#!/bin/sh
set -ex

tar -xof "zig-${MINIMAL_ARG_VERSION}.tar.xz"
cd "zig-${MINIMAL_ARG_VERSION}"

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

cmake -B build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="${MINIMAL_ARG_PREFIX:?build.ncl forwards prefix}" \
  -DCMAKE_PREFIX_PATH=/usr \
  -DZIG_SHARED_LLVM=ON \
  -DZIG_TARGET_MCPU=baseline

ninja -C build
DESTDIR=$OUTPUT_DIR ninja -C build install

# Prefixed: nothing may land in /usr/bin or /usr/lib/zig (zig 0.17's paths).
test -x "$OUTPUT_DIR$MINIMAL_ARG_PREFIX/bin/zig"
test ! -e "$OUTPUT_DIR/usr/bin/zig"
test ! -e "$OUTPUT_DIR/usr/lib/zig"
