#!/bin/sh
# Imported from Wolfi `brotli` (1.2.0, cmake) by pkgmgr import-wolfi.
# CMAKE_INSTALL_LIBDIR=lib so the installed .pc files reference usr/lib, not the
# GNUInstallDirs 64-bit default lib64 (the libs land in usr/lib).
set -eu
cmake -S . -B build -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_INSTALL_LIBDIR=lib -DCMAKE_BUILD_TYPE=Release -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DBROTLI_BUILD_FOR_PACKAGE=ON -DCMAKE_POSITION_INDEPENDENT_CODE=ON
cmake --build build -j"$(nproc)"
DESTDIR="$OUTPUT_DIR" cmake --install build
