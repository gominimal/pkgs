#!/bin/sh
# Imported from Wolfi `jsoncpp` (1.9.8, cmake) by pkgmgr import-wolfi.
# Shared-only build. Wolfi ships jsoncpp's static lib in a -dev subpackage (and
# passed -DCMAKE_POSITION_INDEPENDENT_CODE=ON for it); Minimal ships shared, so
# turn the static/object libs OFF — otherwise the installed cmake export makes
# `JsonCpp::JsonCpp` resolve to the (unpackaged) static target and downstream
# find_package() link breaks.
set -eu
# Reproducibility flags (see AGENTS.md).
export CFLAGS="${CFLAGS:-} -ffile-prefix-map=$(pwd)=/builddir -gno-record-gcc-switches"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="${LDFLAGS:-} -Wl,--build-id=none"
export ARFLAGS=Drc
# CMAKE_INSTALL_LIBDIR=lib: jsoncpp's GNUInstallDirs defaults to lib64 on 64-bit,
# which makes the installed .pc/cmake config point at usr/lib64 while the lib
# lands in usr/lib — pin it to lib so metadata and files agree.
cmake -S . -B build -G Ninja -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_INSTALL_LIBDIR=lib -DCMAKE_BUILD_TYPE=Release -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DBUILD_STATIC_LIBS=OFF -DBUILD_OBJECT_LIBS=OFF
cmake --build build -j"$(nproc)"
DESTDIR="$OUTPUT_DIR" cmake --install build
