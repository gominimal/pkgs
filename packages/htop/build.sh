#!/bin/sh
set -e

# Generate configure script
autoreconf -fi

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe"
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
