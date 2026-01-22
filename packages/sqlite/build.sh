#!/bin/sh
set -e

tar xfo sqlite-autoconf-3500400.tar.gz
cd sqlite-autoconf-3500400

export CFLAGS="-DSQLITE_ENABLE_COLUMN_METADATA -march=x86-64-v3 -O2 -pipe"

./configure  --prefix=/usr         \
            --disable-static       \
            --enable-fts4          \
            --enable-fts5          \
            --enable-rtree         \
            --enable-session

make -j$(nproc)

make DESTDIR="$OUTPUT_DIR" install
