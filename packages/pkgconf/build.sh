#!/bin/sh
set -e

export CFLAGS="-march=x86-64-v3 -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

./configure  --prefix=/usr      \
            --disable-static    \
            --docdir="/usr/share/doc/pkgconf-2.5.1"

make -j$(nproc)
make DESTDIR=$OUTPUT_DIR install

ln -sv pkgconf $OUTPUT_DIR/usr/bin/pkg-config
