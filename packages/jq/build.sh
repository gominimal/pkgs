#!/bin/sh
set -e

ls -lah
cd "jq-${MINIMAL_ARG_VERSION}"

export CFLAGS="-march=x86-64-v3 -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

./configure --prefix=/usr                   \
            --with-oniguruma=builtin

make -j$(nproc)
make DESTDIR=$OUTPUT_DIR install
