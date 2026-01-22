#!/bin/sh
set -e

tar xfo "icu4c-${MINIMAL_ARG_VERSION}-sources.tgz"
cd icu/source

export CFLAGS="-march=x86-64-v3 -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

./configure --prefix=/usr

make -j$(nproc)
make DESTDIR=$OUTPUT_DIR install
