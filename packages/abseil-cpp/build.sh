#!/bin/sh
set -e

mkdir build &&
cd    build

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

cmake -D CMAKE_INSTALL_PREFIX=/usr      \
      -D CMAKE_INSTALL_LIBDIR=/usr/lib  \
      -D CMAKE_BUILD_TYPE=Release       \
      -D CMAKE_CXX_STANDARD=17          \
      -D CMAKE_CXX_STANDARD_REQUIRED=ON \
      -D ABSL_PROPAGATE_CXX_STD=ON      \
      -D BUILD_SHARED_LIBS=ON           \
      -G Ninja ..
ninja

DESTDIR="$OUTPUT_DIR" ninja install

# CMAKE_CXX_STANDARD=17: abseil's install bakes the standard it was built with
# into absl/base/options.h. Left to the compiler default, gcc 16 (gnu++20)
# bakes ABSL_OPTION_USE_STD_ORDERING 1, and every consumer that compiles with
# -std=c++17 then fails on `using std::partial_ordering` (the smoketest did,
# gcc 16.2 canary pkgs#1340 run 34ab070b). C++17 is what gcc 15 built.
# CMAKE_CXX_STANDARD_REQUIRED is needed too: without it CMake/AbseilDll.cmake
# ignores CMAKE_CXX_STANDARD and test-compiles against the compiler default.
opts="$OUTPUT_DIR/usr/include/absl/base/options.h"
grep -q '^#define ABSL_OPTION_USE_STD_ORDERING 0' "$opts" || {
  echo "abseil-cpp: $opts does not pin ABSL_OPTION_USE_STD_ORDERING 0" >&2
  grep -n 'ABSL_OPTION_USE_STD_ORDERING' "$opts" >&2 || true
  exit 1
}
