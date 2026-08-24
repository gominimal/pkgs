#!/bin/sh
# Imported from Wolfi `re2` (2025-11-05, cmake) by pkgmgr import-wolfi.
# CMAKE_INSTALL_LIBDIR=lib so the installed .pc + cmake export reference usr/lib
# (GNUInstallDirs defaults to lib64 on 64-bit → a find_package(re2) FATAL_ERROR).
set -eu
# Reproducibility flags (see AGENTS.md).
export CFLAGS="${CFLAGS:-} -ffile-prefix-map=$(pwd)=/builddir -gno-record-gcc-switches"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="${LDFLAGS:-} -Wl,--build-id=none"
export ARFLAGS=Drc
cmake -S . -B build -G Ninja -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_INSTALL_LIBDIR=lib -DCMAKE_BUILD_TYPE=Release -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DBUILD_SHARED_LIBS=ON -DRE2_USE_ICU=ON -DRE2_BUILD_TESTING="OFF"
cmake --build build -j"$(nproc)"
DESTDIR="$OUTPUT_DIR" cmake --install build
