#!/bin/sh
set -e

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"

# Threads through pthreads; atomics from the compiler's builtins, so no libatomic_ops.
./configure --prefix=/usr \
            --disable-static \
            --disable-docs \
            --enable-threads=posix \
            --with-libatomic-ops=none

make -j"$(nproc)"
make DESTDIR="$OUTPUT_DIR" install
