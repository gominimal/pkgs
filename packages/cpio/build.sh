#!/bin/sh
set -ex

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
# cpio 2.15 uses K&R `int xstat()` declarations; GCC's C23 default reads `()`
# as zero-args and rejects the calls. -std=gnu17 restores the older semantics.
export CFLAGS="$MARCH -O2 -pipe -std=gnu17 -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

./configure --prefix=/usr
make -j"$(nproc)"
make DESTDIR="$OUTPUT_DIR" install
