#!/bin/sh
set -ex

tar xf less-679.tar.gz
cd less-679

export CFLAGS="-march=x86-64-v3 -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

./configure --prefix=/usr --sysconfdir=/etc

make -j$(nproc)
make DESTDIR="$OUTPUT_DIR" install
