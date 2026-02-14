#!/bin/sh
set -e

cd "findutils-${MINIMAL_ARG_VERSION}"

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

./configure --prefix=/usr --localstatedir=/var/lib/locate

make -j$(nproc)
# TODO "locate: 'failed to drop group privileges': Operation not permitted"
# make check
make DESTDIR=$OUTPUT_DIR install-strip
