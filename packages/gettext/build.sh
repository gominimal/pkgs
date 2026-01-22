#!/bin/sh
set -e

export CFLAGS="-march=x86-64-v3 -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

./configure  --prefix=/usr      \
            --disable-static    \
            --docdir=/usr/share/doc/gettext-0.26

make -j$(nproc)
# make check # TODO: Move somewhere else
make DESTDIR="$OUTPUT_DIR" install
chmod -v 0755 "$OUTPUT_DIR/usr/lib/preloadable_libintl.so"
