#!/bin/sh
set -e

# Generate configure script
autoreconf -fi

# Configure with ncurses support
./configure \
    --prefix=/usr \
    --disable-static \
    --enable-unicode

# Build
make -j$(nproc)

# Install
make DESTDIR="$OUTPUT_DIR" install
