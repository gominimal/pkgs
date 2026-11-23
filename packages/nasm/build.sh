#!/bin/sh
set -ex

# Security backport (see build.ncl). `set -e` plus patch's non-zero exit on a
# rejected hunk means a stale patch ABORTS the build rather than silently
# shipping an unpatched nasm.
patch -Np1 -i "CVE-2026-6067.patch"   # output/outobj.c  GROUP segs[GROUP_MAX] heap overflow (8890d723)

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

./configure --prefix=/usr
make -j$(nproc)
make DESTDIR=$OUTPUT_DIR install
