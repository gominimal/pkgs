#!/bin/sh
set -ex

export CFLAGS="-march=x86-64-v3 -O2 -pipe"
export CXXFLAGS="${CFLAGS}"

cmake -B build \
  -DCMAKE_INSTALL_PREFIX=/usr \
  -DCMAKE_INSTALL_LIBDIR=lib \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DLIBXML2_WITH_PYTHON=OFF \
  -DLIBXML2_WITH_ICU=ON \
  -DLIBXML2_WITH_LZMA=ON \
  -DLIBXML2_WITH_ZLIB=ON \
  -DBUILD_SHARED_LIBS=ON

cmake --build build -j$(nproc)
DESTDIR=$OUTPUT_DIR cmake --install build
