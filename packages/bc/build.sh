#!/bin/sh
set -e

tar xfo "bc-${MINIMAL_ARG_VERSION}.tar.xz"
cd "bc-${MINIMAL_ARG_VERSION}"

export CFLAGS="-march=x86-64-v3 -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

CC="gcc -std=c99" ./configure --prefix=/usr --disable-generated-tests --enable-readline

make -j$(nproc)
make test
make DESTDIR=$OUTPUT_DIR install
