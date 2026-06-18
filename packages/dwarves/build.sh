#!/bin/sh
set -e

mkdir build &&
cd    build

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CC=gcc
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"

# Build pahole against the SYSTEM libbpf (the libbpf pkgs package) instead of the
# vendored git submodule — the GitHub archive tarball does not include submodules,
# and LIBBPF_EMBEDDED=OFF makes dwarves discover libbpf via pkg-config.
cmake -D CMAKE_INSTALL_PREFIX=/usr     \
      -D CMAKE_INSTALL_LIBDIR=/usr/lib \
      -D __LIB=lib                     \
      -D CMAKE_BUILD_TYPE=Release      \
      -D LIBBPF_EMBEDDED=OFF           \
      -G Ninja ..

ninja

DESTDIR="$OUTPUT_DIR" ninja install

find "$OUTPUT_DIR" -name '*.la' -delete
