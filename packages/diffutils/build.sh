#!/bin/sh
set -e

cd "diffutils-${MINIMAL_ARG_VERSION}"

export CFLAGS="-march=x86-64-v3 -O3 -pipe"
export CXXFLAGS="${CFLAGS}"

./configure --prefix=/usr

make -j$(nproc)
make check
make DESTDIR=$OUTPUT_DIR install-strip
