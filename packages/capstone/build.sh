#!/bin/sh
set -eu

# Security backports (see build.ncl for what each one is and where it comes
# from). `set -e` plus patch's non-zero exit on a rejected hunk means a stale
# patch ABORTS the build rather than shipping an unpatched libcapstone. Order
# matters: the decode_long port applies on top of e17ee44a.
patch -Np1 -i CVE-2026-55893-55894-sh-bounds.patch       # SH operand/decode-table bounds (e17ee44a, v5)
patch -Np1 -i GHSA-5q63-4654-94v6-sh-decode-long.patch   # SH failed 32-bit decode falls through (de4b58b2, ported)
patch -Np1 -i CVE-2026-49282-m68k-insn-name.patch        # M68K_insn_name off-by-one (7441aee2)
patch -Np1 -i GHSA-8qp8-2vg2-8mr4-mcinst-memset.patch    # zero MCInst per instruction (cc6f8e07, v5)

# Reproducibility flags (see AGENTS.md).
export CFLAGS="${CFLAGS:-} -ffile-prefix-map=$(pwd)=/builddir -gno-record-gcc-switches"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="${LDFLAGS:-} -Wl,--build-id=none"
export ARFLAGS=Drc

# BUILD_SHARED_LIBS defaults to OFF and BUILD_STATIC_LIBS to ON upstream — the
# opposite of what a distro wants. Left alone, this package would ship
# libcapstone.a and every consumer would absorb capstone statically, which puts
# a capstone CVE beyond pkgscan's reach: nothing in the consumer's tree would
# name capstone at all. So shared on, static off, deliberately.
#
# CMAKE_INSTALL_LIBDIR=lib keeps the installed .pc and cmake files pointing at
# usr/lib rather than the GNUInstallDirs 64-bit default lib64.
#
# CAPSTONE_ARCHITECTURE_DEFAULT=ON is the upstream default and is set here
# explicitly because it is load-bearing: it gates every per-architecture
# CAPSTONE_<ARCH>_SUPPORT option at once, and turning it off yields a working
# cstool that silently cannot disassemble whole architectures. The
# `disassembles` test pins the consequence rather than trusting this line.
#
# Tests off: upstream's suite needs its own fixtures and adds build time; the
# standalone tests in build.ncl assert the properties we actually care about.
cmake -S . -B build -G Ninja \
  -DCMAKE_INSTALL_PREFIX=/usr \
  -DCMAKE_INSTALL_LIBDIR=lib \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=ON \
  -DBUILD_STATIC_LIBS=OFF \
  -DCAPSTONE_BUILD_CSTOOL=ON \
  -DCAPSTONE_BUILD_TESTS=OFF \
  -DCAPSTONE_BUILD_CSTEST=OFF \
  -DCAPSTONE_ARCHITECTURE_DEFAULT=ON \
  -DCAPSTONE_X86_REDUCE=OFF

cmake --build build -j"$(nproc)"
DESTDIR="$OUTPUT_DIR" cmake --install build

# Regression tests for the backports, run at build time because they need
# AddressSanitizer: each bug is a read or write a few bytes past an array, and
# an uninstrumented libcapstone survives that silently. So build a scratch
# static libcapstone with only the affected architectures under ASan, link
# cve-regress.c against it, and run every case. Unpatched, ASan aborts (or a
# case's own check fails) and so does the build. Scratch only, never installed.
cmake -S . -B build-asan -G Ninja \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DCMAKE_C_FLAGS="-fsanitize=address -fno-omit-frame-pointer" \
  -DBUILD_SHARED_LIBS=OFF \
  -DBUILD_STATIC_LIBS=ON \
  -DCAPSTONE_BUILD_CSTOOL=OFF \
  -DCAPSTONE_BUILD_TESTS=OFF \
  -DCAPSTONE_BUILD_CSTEST=OFF \
  -DCAPSTONE_INSTALL=OFF \
  -DCAPSTONE_ARCHITECTURE_DEFAULT=OFF \
  -DCAPSTONE_SH_SUPPORT=ON \
  -DCAPSTONE_M68K_SUPPORT=ON \
  -DCAPSTONE_RISCV_SUPPORT=ON
cmake --build build-asan -j"$(nproc)"
gcc -O1 -g -fsanitize=address -fno-omit-frame-pointer -I include \
  -o build-asan/cve-regress cve-regress.c build-asan/libcapstone.a

# The same program against the library being shipped: no ASan there, but the
# cases' own checks (op_count bound, NULL insn names) still have to hold.
gcc -O1 -g -I include -o build/cve-regress cve-regress.c -L build -lcapstone

for c in sh-fallthrough-oob-write sh-fallthrough-table-read \
         CVE-2026-55893 CVE-2026-55894 GHSA-5q63-4654-94v6 \
         CVE-2026-49282-m68k CVE-2026-49282-riscv; do
  echo "== $c (ASan)"
  ASAN_OPTIONS=detect_leaks=0:abort_on_error=0 ./build-asan/cve-regress "$c"
  echo "== $c (shipped libcapstone.so)"
  LD_LIBRARY_PATH="$(pwd)/build" ./build/cve-regress "$c"
done
