#!/bin/sh
set -e

export CFLAGS="-march=x86-64-v3 -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

./configure  --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/acl-2.3.2

make -j$(nproc)
# make check # TODO "opening /etc/group: No such file or directory"
make DESTDIR="$OUTPUT_DIR" install
