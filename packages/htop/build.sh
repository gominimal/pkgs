#!/bin/sh
set -e

# Generate configure script
autoreconf -fi

export CFLAGS="-march=x86-64-v3 -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

# Configure with ncurses support
./configure \
    --prefix=/usr \
    --disable-static \
    --enable-unicode

# Build
make -j$(nproc)

# Install
make DESTDIR="$OUTPUT_DIR" install
