#!/bin/sh
# Imported from Wolfi `zeromq` (4.3.5, cmake) by pkgmgr import-wolfi.
# CMAKE_INSTALL_LIBDIR=lib so the .pc/cmake export reference usr/lib (else lib64
# → find_package(ZeroMQ) FATAL_ERROR). BUILD_STATIC=OFF drops the static lib
# (Minimal ships shared) whose dangling cmake target also pointed at a missing
# archive. WITH_PERF_TOOL=OFF drops the generically-named perf benchmarks
# (local_lat/remote_thr/…) from usr/bin; curve_keygen is under ENABLE_CURVE.
set -eu
# Reproducibility flags (see AGENTS.md).
export CFLAGS="${CFLAGS:-} -ffile-prefix-map=$(pwd)=/builddir -gno-record-gcc-switches"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="${LDFLAGS:-} -Wl,--build-id=none"
export ARFLAGS=Drc
# Wolfi patches (applied before configure).
patch -Np1 -i "0001-cmake-add-curve_keygen-binary.patch"
cmake -S . -B build -G Ninja -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_INSTALL_LIBDIR=lib -DCMAKE_BUILD_TYPE=Release -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DBUILD_STATIC=OFF -DWITH_PERF_TOOL=OFF -DENABLE_CURVE=ON -DWITH_LIBSODIUM=ON
cmake --build build -j"$(nproc)"
DESTDIR="$OUTPUT_DIR" cmake --install build
