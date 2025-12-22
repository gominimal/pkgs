#!/bin/sh
set -e

./configure --prefix=/usr     \
            --sysconfdir=/etc \
            --enable-utf8     \
            --docdir=/usr/share/doc/nano-$MINIMAL_ARG_VERSION
make -j$(nproc)

make DESTDIR="$OUTPUT_DIR" install
install -v -m644 doc/{nano.html,sample.nanorc} "${OUTPUT_DIR}/usr/share/doc/nano-${MINIMAL_ARG_VERSION}"
