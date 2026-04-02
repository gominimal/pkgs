#!/bin/sh
set -ex

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

cmake -B build \
  -DCMAKE_INSTALL_PREFIX=/usr \
  -DCMAKE_INSTALL_LIBDIR=lib \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DZ3_BUILD_PYTHON_BINDINGS=OFF \
  -DZ3_BUILD_JAVA_BINDINGS=OFF \
  -DZ3_BUILD_DOTNET_BINDINGS=OFF \
  -DBUILD_SHARED_LIBS=ON

cmake --build build -j$(nproc)
DESTDIR=$OUTPUT_DIR cmake --install build
