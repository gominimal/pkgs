#!/bin/sh
set -e

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

./configure  --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/acl-2.3.2

make -j$(nproc)
# make check # TODO "opening /etc/group: No such file or directory"
make DESTDIR="$OUTPUT_DIR" install
