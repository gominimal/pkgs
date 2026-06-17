#!/bin/sh
set -e

tar -xof "elfutils-${MINIMAL_ARG_VERSION}.tar.bz2"
cd "elfutils-${MINIMAL_ARG_VERSION}"

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
# -Wno-error=discarded-qualifiers: glibc 2.43's ISO C23 const-preserving
# bsearch/strchr-family return const for const args; elfutils assigns those to
# plain pointers (libcpu/riscv_disasm.c known_csrs bsearch) under its default-on
# -Werror. elfutils' configure has no --disable-werror in this version, but
# automake emits `$(AM_CFLAGS) $(CFLAGS)`, so a CFLAGS flag lands after
# elfutils' AM_CFLAGS -Werror and wins. Same glibc-2.43 C23 FTBFS class as #238.
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -Wl,--build-id=none -ffile-prefix-map=$(pwd)=/builddir -Wno-error=discarded-qualifiers"
export LDFLAGS="-Wl,--build-id=none"
export ARFLAGS=Drc
export CXXFLAGS="${CFLAGS}"

./configure --prefix=/usr                \
            --disable-debuginfod         \
            --enable-libdebuginfod=dummy

make -j$(nproc)

make DESTDIR="$OUTPUT_DIR" install
