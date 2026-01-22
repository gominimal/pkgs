#!/bin/sh
set -e

tar xfo "libuv-${MINIMAL_ARG_VERSION}.tar.gz"
cd "libuv-${MINIMAL_ARG_VERSION}"

export CFLAGS="-march=x86-64-v3 -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

./autogen.sh
./configure --prefix=/usr --disable-static

make -j$(nproc)
make DESTDIR=$OUTPUT_DIR install
