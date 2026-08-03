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
# The CMake build offers no `find_package(ZLIB)` or system-lib option of any
# kind — unlike rizin, where seventeen `use_sys_*` flags exist and flipping
# them was the whole job. Here there is nothing to flip.
#
# It is also not an oversight: the compressed data written by `upx` is read
# back by a decompression STUB that upx welds onto the packed executable, so
# the compressor and the stub must agree bit-for-bit. Swapping in a system
# zlib would produce files this upx's own stubs could not unpack.
#
# WHAT IS ACTUALLY LINKED IN is narrower than what sits in vendor/, and the
# difference matters because it is what license_spdx has to name. Established
# from the build rather than assumed — the ninja log compiles exactly two
# vendor targets, upx_vendor_ucl and upx_vendor_zlib:
#
#   ucl        GPL-2.0-or-later. Linked.
#   zlib       Zlib licence. Linked.
#   lzma-sdk   Public domain. Linked, but invisibly: it has no CMake target
#              because src/compress/compress_lzma.cpp `#include`s its .cpp
#              files DIRECTLY (lines 273+), so it never appears as its own
#              objects in the build log.
#   doctest    MIT. Linked via src/check/dt_impl.cpp, which does the same
#              trick with doctest.cpp — this is a release binary that carries
#              its test framework.
#   bzip2      NOT linked. CMakeLists.txt:269 `set(UPX_CONFIG_DISABLE_BZIP2 ON)`
#   zstd       NOT linked. CMakeLists.txt:270 `set(UPX_CONFIG_DISABLE_ZSTD ON)`
#              ("currently not used; maybe in UPX version 6")
#
# The consequence still has to be stated rather than discovered: the three
# libraries that ARE linked are INVISIBLE to pkgscan here. A CVE in the
# bundled zlib will not appear against this package, because nothing in the
# tree names it. A real, permanent blind spot on this package — not a TODO
# someone can close.
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
