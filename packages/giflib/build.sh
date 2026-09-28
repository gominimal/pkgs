#!/bin/sh
set -ex
case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
# The Makefile has no configure step; its OFLAGS carry the optimisation flags and LDFLAGS the link flags.
# Library targets only: `all` also builds the utilities and runs doc/ through ImageMagick's convert.
make CC=gcc OFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir" LDFLAGS="-Wl,--build-id=none" PREFIX=/usr libgif.so libgif.a
make install-include install-lib PREFIX=/usr DESTDIR="$OUTPUT_DIR"
