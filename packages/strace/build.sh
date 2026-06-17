#!/bin/sh
set -e

tar -xof strace-6.17.tar.xz
cd strace-6.17

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
# -Wno-error=discarded-qualifiers: glibc 2.43's ISO C23 const-preserving bsearch
# returns const for a const arg; strace's ioctl.c assigns it to a plain pointer
# (iop = bsearch(..., ioctlent, ...)) under its default-on -Werror. Lands after
# strace's -Werror on the compile line so the later flag wins. glibc-2.43 class, #238.
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir -Wno-error=discarded-qualifiers"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

./configure --prefix=/usr --enable-mpers=check
make -j$(nproc)

make DESTDIR="$OUTPUT_DIR" install
