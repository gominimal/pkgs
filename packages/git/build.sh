#!/bin/sh
set -e

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

./configure --prefix=/usr                   \
            --with-gitconfig=/etc/gitconfig \
            --with-python=python3           \
            --with-libpcre2

make -j$(nproc)
make DESTDIR=$OUTPUT_DIR NO_INSTALL_HARDLINKS=1 install

find -L "${OUTPUT_DIR}/usr/bin" -xtype f -executable | xargs strip --strip-debug || true
find -L "${OUTPUT_DIR}/usr/libexec/git-core" -xtype f -executable | xargs strip --strip-debug || true
