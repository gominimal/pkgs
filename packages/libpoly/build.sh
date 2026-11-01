#!/bin/sh
set -eu

# The Source strips the libpoly-<version>/ top directory (strip_prefix), so
# the tree is already the working directory.

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
REPRO="-ffile-prefix-map=$(pwd)=/builddir -gno-record-gcc-switches"
export CFLAGS="$MARCH -O2 -pipe $REPRO"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="-Wl,--build-id=none"

# src/CMakeLists.txt appends `-Wall -Werror -Wextra` AFTER the caller's flags,
# so a new warning in a newer gcc fails the build and no -Wno-error from
# CFLAGS can override it. Keep the warnings, drop the -Werror (a developer
# policy, not a correctness check). Fail loudly if upstream moves it.
grep -q -- '-Wall -Werror -Wextra' src/CMakeLists.txt
sed -i 's/-Wall -Werror -Wextra/-Wall -Wextra/g' src/CMakeLists.txt

# Shared libraries only, which is what cvc5 (BUILD_SHARED_LIBS=ON) looks for:
# FindPoly.cmake wants libpoly.so + libpolyxx.so, not the static PIC pair.
cmake -S . -B build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/usr \
  -DLIBPOLY_BUILD_PYTHON_API=OFF \
  -DLIBPOLY_BUILD_STATIC=OFF \
  -DLIBPOLY_BUILD_STATIC_PIC=OFF \
  -DBUILD_TESTING=OFF
ninja -C build
DESTDIR="$OUTPUT_DIR" ninja -C build install

# The install rules hard-code DESTINATION lib; check the layout consumers
# (and this package's output globs) rely on.
test -e "$OUTPUT_DIR/usr/lib/libpoly.so.0"
test -e "$OUTPUT_DIR/usr/lib/libpolyxx.so.0"
test -f "$OUTPUT_DIR/usr/include/poly/version.h"
