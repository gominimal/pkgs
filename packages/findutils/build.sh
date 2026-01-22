#!/bin/sh
set -e

cd "findutils-${MINIMAL_ARG_VERSION}"

export CFLAGS="-march=x86-64-v3 -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

./configure --prefix=/usr --localstatedir=/var/lib/locate

make -j$(nproc)
# TODO "locate: 'failed to drop group privileges': Operation not permitted"
# make check
make DESTDIR=$OUTPUT_DIR install-strip
