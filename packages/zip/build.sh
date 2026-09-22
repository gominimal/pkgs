#!/bin/sh
set -ex
case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
# Info-ZIP is K&R C: under a C23-default gcc its configure probes fail and zip.h then redeclares memset/memcpy.
export CFLAGS="$MARCH -O2 -pipe -std=gnu89 -Wno-implicit-function-declaration -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
# unix/Makefile's `generic` target runs its own feature probes; pass the flags through its variables.
make -f unix/Makefile generic CC=gcc CFLAGS_NOOPT="$CFLAGS -DUNIX -I." LFLAGS1="$LDFLAGS"
mkdir -p "$OUTPUT_DIR/usr/bin" "$OUTPUT_DIR/usr/share/man/man1"
make -f unix/Makefile install prefix=/usr BINDIR="$OUTPUT_DIR/usr/bin" MANDIR="$OUTPUT_DIR/usr/share/man/man1"
