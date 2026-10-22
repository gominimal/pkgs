#!/bin/sh
set -ex
# CVE-2026-26740 -- upstream commit 0616050 (giflib master, 2026-06-01), not in any
# release yet: 6.1.3 still writes the 4-byte GCB into an existing Graphics Control
# Extension block without checking its ByteCount. Applied before the build so a
# failed hunk fails the build under `set -e` instead of shipping an unpatched lib.
patch -Np1 -i ./0001-CVE-2026-26740-egif-gcb-bounds-check.patch
case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
# The Makefile has no configure step; its OFLAGS carry the optimisation flags and LDFLAGS the link flags.
# Library targets only: `all` also builds the utilities (the CLI tools the gif2rgb / giftool CVEs live in).
make CC=gcc OFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir" LDFLAGS="-Wl,--build-id=none" PREFIX=/usr libgif.so libgif.a
make install-include install-lib PREFIX=/usr DESTDIR="$OUTPUT_DIR"
