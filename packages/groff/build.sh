#!/bin/sh
set -e

tar xf "groff-${MINIMAL_ARG_VERSION}.tar.gz"
cd "groff-${MINIMAL_ARG_VERSION}"

export CFLAGS="-march=x86-64-v3 -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

./configure --prefix=/usr

make -j$(nproc)
make check
make DESTDIR="$OUTPUT_DIR" install
