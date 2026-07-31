#!/bin/sh
set -eu

# Unpacked here rather than by the fetcher: upstream's .tar.xz carries an xz
# SHA-256 integrity check, which the fetcher's decoder does not implement
# ("compression error: Unsupported SHA-256 checksum"). The system tar handles
# it, so the Source stays un-extracted and this does the work.
tar -xof "upx-${MINIMAL_ARG_VERSION}-src.tar.xz"
cd "upx-${MINIMAL_ARG_VERSION}-src"

# Reproducibility flags (see AGENTS.md).
export CFLAGS="${CFLAGS:-} -ffile-prefix-map=$(pwd)=/builddir -gno-record-gcc-switches"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="${LDFLAGS:-} -Wl,--build-id=none"
export ARFLAGS=Drc

# UPX BUNDLES ITS COMPRESSORS AND THAT IS NOT A CONFIGURATION CHOICE.
#
# vendor/ carries ucl, lzma-sdk, zlib, zstd, bzip2 (plus doctest and valgrind
# headers), and the CMake build offers no `find_package(ZLIB)` or system-lib
# option of any kind — unlike rizin, where seven `use_sys_*` flags exist and
# flipping them was the whole job. Here there is nothing to flip.
#
# It is also not an oversight: the compressed data written by `upx` is read
# back by a decompression STUB that upx welds onto the packed executable, so
# the compressor and the stub must agree bit-for-bit. Swapping in a system
# zlib would produce files this upx's own stubs could not unpack.
#
# The consequence still has to be stated rather than discovered: those five
# libraries are INVISIBLE to pkgscan here. A CVE in the bundled zlib or zstd
# will not appear against this package, because nothing in the tree names
# them. Called out in the PR body too — this is a real, permanent blind spot
# on this package, not a TODO someone can close.
#
# UPX_CONFIG_DISABLE_GITREV=ON: without it the build stamps a git revision
# into the binary. There is no .git here (we build from the -src tarball), so
# it would stamp an empty/unknown value — but making it explicit keeps the
# output independent of whether a .git ever appears in the build tree, which
# is a reproducibility property, not a cosmetic one.
#
# GNUInstallDirs is included by upstream only when CMAKE_INSTALL_PREFIX is
# set, and the whole install() block is guarded on CMAKE_INSTALL_BINDIR being
# DEFINED — so the prefix below is what makes `cmake --install` do anything at
# all. Drop it and the build succeeds and installs nothing.
cmake -S . -B build -G Ninja \
  -DCMAKE_INSTALL_PREFIX=/usr \
  -DCMAKE_BUILD_TYPE=Release \
  -DUPX_CONFIG_DISABLE_GITREV=ON

cmake --build build -j"$(nproc)"
DESTDIR="$OUTPUT_DIR" cmake --install build
