#!/bin/sh
set -e

cd "findutils-${MINIMAL_ARG_VERSION}"

./configure --prefix=/usr --localstatedir=/var/lib/locate

make -j$(nproc)
# TODO "locate: 'failed to drop group privileges': Operation not permitted"
# make check
make DESTDIR=$OUTPUT_DIR install-strip
