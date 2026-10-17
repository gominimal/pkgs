#!/bin/bash
set -euo pipefail


# The grpc-proto submodule (see build.ncl): the tag archive ships it empty.
mkdir -p third_party/grpc-proto
tar -xof ec30f589e2519d595688b9a42f88a91bdd6b733f.tar.gz -C third_party/grpc-proto --strip-components=1
test -f third_party/grpc-proto/grpc/reflection/v1/reflection.proto

export CFLAGS="-O3 -pipe -ffile-prefix-map=$(pwd)=/builddir -gno-record-gcc-switches"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="-Wl,--build-id=none"
export ARFLAGS=Drc

cmake -B build \
  -DCMAKE_INSTALL_PREFIX=/usr \
  -DCMAKE_INSTALL_LIBDIR=/usr/lib \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_SHARED_LIBS=ON \
  -DgRPC_INSTALL=ON \
  -DgRPC_BUILD_TESTS=OFF \
  -DgRPC_ABSL_PROVIDER=package \
  -DgRPC_CARES_PROVIDER=package \
  -DgRPC_PROTOBUF_PROVIDER=package \
  -DgRPC_RE2_PROVIDER=package \
  -DgRPC_SSL_PROVIDER=package \
  -DgRPC_ZLIB_PROVIDER=package \
  -DgRPC_DOWNLOAD_ARCHIVES=OFF \
  -DCMAKE_CXX_STANDARD=14
make -C build -j$(nproc)
make DESTDIR=$OUTPUT_DIR -C build install
