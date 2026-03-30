#!/bin/bash
set -euo pipefail

mkdir build
cd build

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export SOURCE_DATE_EPOCH=0
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="$CFLAGS"

cmake -G Ninja \
  -DCMAKE_INSTALL_PREFIX=/usr \
  -DCMAKE_INSTALL_LIBDIR=/usr/lib \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_SKIP_INSTALL_RPATH=ON \
  -DBUILD_SHARED_LIBS=ON \
  -DBUILD_DEPS=ON \
  -DBUILD_CXX=ON \
  -DBUILD_PYTHON=OFF \
  -DBUILD_JAVA=OFF \
  -DBUILD_DOTNET=OFF \
  -DBUILD_SAMPLES=OFF \
  -DBUILD_EXAMPLES=OFF \
  -DBUILD_TESTING=OFF \
  -DUSE_SCIP=ON \
  -DUSE_HIGHS=ON \
  -DUSE_COINOR=ON \
  -DUSE_GLPK=OFF \
  -DUSE_GUROBI=OFF \
  -DUSE_CPLEX=OFF \
  -DUSE_XPRESS=OFF \
  -DCMAKE_EXE_LINKER_FLAGS="-Wl,--unresolved-symbols=ignore-in-shared-libs" \
  ..

# protoc and other build-time tools need to find their shared libs
export LD_LIBRARY_PATH="$(pwd)/usr/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

ninja -j$(nproc)

DESTDIR="$OUTPUT_DIR" ninja install
