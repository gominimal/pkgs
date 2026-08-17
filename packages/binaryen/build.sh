#!/bin/sh
set -ex

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac

export CFLAGS="$MARCH -O3 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="-Wl,--build-id=none"
export ARFLAGS=Drc

# ENABLE_WERROR is on by default upstream, which turns any new warning from a
# newer gcc into a build failure. BUILD_TESTS pulls in a googletest checkout
# that the release tarball does not carry.
# CMake defaults LIBDIR to lib64 on this platform; everything else in the
# registry installs libraries to usr/lib.
cmake -B build \
  -DCMAKE_INSTALL_PREFIX=/usr \
  -DCMAKE_INSTALL_LIBDIR=lib \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_TESTS=OFF \
  -DENABLE_WERROR=OFF

cmake --build build -j"$(nproc)"
DESTDIR="$OUTPUT_DIR" cmake --install build
