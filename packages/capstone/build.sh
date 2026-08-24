#!/bin/sh
set -eu

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
