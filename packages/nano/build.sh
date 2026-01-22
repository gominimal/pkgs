#!/bin/sh
set -e

export CFLAGS="-march=x86-64-v3 -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

./configure --prefix=/usr     \
            --sysconfdir=/etc \
            --enable-utf8     \
            --docdir=/usr/share/doc/nano-$MINIMAL_ARG_VERSION
make -j$(nproc)

make DESTDIR="$OUTPUT_DIR" install
install -v -m644 doc/{nano.html,sample.nanorc} "${OUTPUT_DIR}/usr/share/doc/nano-${MINIMAL_ARG_VERSION}"
