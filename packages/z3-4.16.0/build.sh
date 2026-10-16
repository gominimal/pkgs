#!/bin/sh
# z3 pinned at 4.16.0 for Verus, which refuses any other version. Installed as
# a single statically linked binary, /usr/bin/z3-4.16.0, so it sits next to
# the `z3` package (5.x, /usr/bin/z3) without colliding.
set -ex

# Unlike packages/z3, no -march=x86-64-v3: a pinned verification solver should
# run on any x86-64 host.
export CFLAGS="-O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="-Wl,--build-id=none"

cmake -B build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DZ3_BUILD_LIBZ3_SHARED=OFF \
  -DZ3_BUILD_PYTHON_BINDINGS=OFF \
  -DZ3_BUILD_JAVA_BINDINGS=OFF \
  -DZ3_BUILD_DOTNET_BINDINGS=OFF \
  -DZ3_BUILD_TEST_EXECUTABLES=OFF
cmake --build build -j"$(nproc)"

mkdir -p "$OUTPUT_DIR/usr/bin"
cp build/z3 "$OUTPUT_DIR/usr/bin/z3-$MINIMAL_ARG_VERSION"
