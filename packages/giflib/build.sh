#!/bin/sh
set -ex
case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
# The Makefile has no configure step; its OFLAGS carry the optimisation flags and LDFLAGS the link flags.
make CC=gcc OFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir" LDFLAGS="-Wl,--build-id=none" PREFIX=/usr
make install-include install-lib PREFIX=/usr DESTDIR="$OUTPUT_DIR"
