#!/bin/sh
set -e

tar -xof "gdb-${MINIMAL_ARG_VERSION}.tar.xz"
cd "gdb-${MINIMAL_ARG_VERSION}"

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac

# Reproducibility flags per the pkgs AGENTS.md C/C++ stack: two builds of the
# same source must be byte-identical.
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="-Wl,--build-id=none"
export ARFLAGS=Drc

# The gdb tarball ships the ENTIRE binutils-gdb tree — bfd, gas, ld, gprof and
# the binutils programs are all in here. Building them would silently produce a
# second `ld`/`objdump`/`as` that collide with our binutils package. Disable all
# of them; we want exactly one binary out of this tree.
#
# --with-python is LOAD-BEARING, not a nicety: gef is a Python extension and
# cannot load into a gdb built without Python support. Since the whole point of
# packaging gdb here is to carry gef, a non-Python gdb would satisfy the build
# and fail the actual goal.
#
# --enable-targets=all costs nothing at build time and lets gdb disassemble
# foreign architectures — which is what makes it useful against a binary being
# emulated under qemu-user's gdbstub, and mirrors the fix the binutils package
# still needs.
#
# MAKEINFO=true skips building the info manuals so we do not have to package
# texinfo for a doc format nothing here reads.
./configure \
  --prefix=/usr \
  --disable-binutils \
  --disable-ld \
  --disable-gas \
  --disable-gprof \
  --disable-gold \
  --disable-sim \
  --disable-nls \
  --disable-werror \
  --with-python=/usr/bin/python3 \
  --with-system-readline \
  --with-system-zlib \
  --enable-targets=all \
  MAKEINFO=true

make -j"$(nproc)" MAKEINFO=true
make install DESTDIR="$OUTPUT_DIR" MAKEINFO=true

# `make install` from this tree also drops libbfd/libopcodes headers and static
# archives that belong to the binutils package. Remove them so the two packages
# cannot disagree about who owns bfd.h.
rm -rf "$OUTPUT_DIR/usr/include" "$OUTPUT_DIR/usr/lib/libbfd."* "$OUTPUT_DIR/usr/lib/libopcodes."*
rm -rf "$OUTPUT_DIR/usr/share/info" "$OUTPUT_DIR/usr/share/locale"
