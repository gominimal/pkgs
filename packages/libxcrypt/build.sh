#!/bin/sh
set -e

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
# -Wno-error=discarded-qualifiers: glibc 2.43's ISO C23 const-preserving
# strchr/strstr/memchr return `const char *` for a `const char *` arg, which
# libxcrypt's crypt-{gost,sm3}-yescrypt.c assign to a plain `char *` — tripping
# libxcrypt's own configure-enabled -Werror. This package has a hand-written
# build.sh (not the make stack), so the stacks/make/stack.ncl fleet lever can't
# reach it; we downgrade only that one warning here, landing after libxcrypt's
# -Werror on the compile line so the later flag wins. Same class as #238.
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir -Wno-error=discarded-qualifiers"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

./configure --prefix=/usr \
            --enable-hashes=strong,glibc \
            --enable-obsolete-api=no \
            --disable-static \
            --disable-failure-tokens

make -j$(nproc)
make check
make DESTDIR="$OUTPUT_DIR" install
