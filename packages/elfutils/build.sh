#!/bin/sh
set -e

tar -xof "elfutils-${MINIMAL_ARG_VERSION}.tar.bz2"
cd "elfutils-${MINIMAL_ARG_VERSION}"

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -Wl,--build-id=none -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export ARFLAGS=Drc
export CXXFLAGS="${CFLAGS}"

# --disable-werror: glibc 2.43's ISO C23 const-preserving lookups (bsearch over
# a const table in libcpu/riscv_disasm.c, etc.) discard const into plain
# pointers, tripping elfutils' default-on -Werror. elfutils trips several
# distinct -Werror warnings across toolchain bumps (it's why distros disable
# werror for it), so we use its own off-switch rather than chase each warning
# with a -Wno-error=... flag. Same glibc-2.43 C23 FTBFS class as #238.
./configure --prefix=/usr                \
            --disable-werror             \
            --disable-debuginfod         \
            --enable-libdebuginfod=dummy

make -j$(nproc)

make DESTDIR="$OUTPUT_DIR" install
