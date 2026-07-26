#!/bin/sh
set -e

cd src

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"

# libbpf's raw Makefile defaults CC to make's built-in `cc`; the toolchain
# provides `gcc`, so pin CC explicitly.
export CC=gcc

# Build + install the shared/static library, API + uapi headers, and the
# pkg-config file (libbpf.pc) that dwarves discovers via -DLIBBPF_EMBEDDED=OFF.
make -j"$(nproc)" CC=gcc PREFIX=/usr LIBDIR=/usr/lib
make CC=gcc PREFIX=/usr LIBDIR=/usr/lib DESTDIR="$OUTPUT_DIR" install install_uapi_headers

# Drop libtool archives for reproducibility/cleanliness.
find "$OUTPUT_DIR" -name '*.la' -delete
