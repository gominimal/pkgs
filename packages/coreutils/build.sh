#!/bin/sh
set -e

tar xf "coreutils-${MINIMAL_ARG_VERSION}.tar.xz"
cd "coreutils-${MINIMAL_ARG_VERSION}"

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O3 -pipe"
export CXXFLAGS="${CFLAGS}"

FORCE_UNSAFE_CONFIGURE=1 ./configure \
    --prefix=/usr \
    --enable-no-install-program=kill,uptime

make -j$(nproc)
make DESTDIR=$OUTPUT_DIR install-strip
