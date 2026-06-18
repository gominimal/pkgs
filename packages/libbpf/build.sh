#!/bin/sh
set -e

cd libbpf-$MINIMAL_ARG_VERSION/src

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export SOURCE_DATE_EPOCH=0

# Build + install the shared/static library, API + uapi headers, and the
# pkg-config file (libbpf.pc) that dwarves discovers via -DLIBBPF_EMBEDDED=OFF.
make -j"$(nproc)" PREFIX=/usr LIBDIR=/usr/lib
make PREFIX=/usr LIBDIR=/usr/lib DESTDIR="$OUTPUT_DIR" install install_uapi_headers

# Drop libtool archives for reproducibility/cleanliness.
find "$OUTPUT_DIR" -name '*.la' -delete
