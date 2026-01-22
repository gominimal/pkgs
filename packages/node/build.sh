#!/bin/sh
set -e

export CC=gcc

tar xfo "node-v${MINIMAL_ARG_VERSION}.tar.xz"
cd "node-v${MINIMAL_ARG_VERSION}"

export CFLAGS="-march=x86-64-v3 -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

./configure --prefix=/usr --with-intl=system-icu --shared-openssl --shared-zlib --shared-sqlite --shared-libuv

make -j$(nproc)
make DESTDIR=$OUTPUT_DIR install
