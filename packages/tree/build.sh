#!/bin/sh
set -ex

# tree ships a plain Makefile, no configure. Its default install target wants
# /usr/local and a `strip`ped binary; override prefix and let the toolchain's
# own flags decide stripping so the build stays reproducible.
export CFLAGS="${CFLAGS:-} -O2 -ffile-prefix-map=$(pwd)=/builddir -gno-record-gcc-switches"
export LDFLAGS="${LDFLAGS:-} -Wl,--build-id=none"

# The toolchain provides `gcc`; tree's Makefile defaults to `cc`, which does
# not exist here (make fails with "cc: No such file or directory").
make -j"$(nproc)" CC=gcc CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS"

install -d "$OUTPUT_DIR/usr/bin"
install -m 755 tree "$OUTPUT_DIR/usr/bin/tree"
