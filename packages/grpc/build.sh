#!/bin/bash
set -euo pipefail


# The grpc-proto submodule (see build.ncl): the tag archive ships it empty.
mkdir -p third_party/grpc-proto
tar -xof dd549fc4ed04b60b0fdd3866b82ef0a7c87c6e4f.tar.gz -C third_party/grpc-proto --strip-components=1
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

# Do not embed a trust store (AGENTS.md). grpc installs its own root bundle as
# usr/share/grpc/roots.pem, a private copy that never gets our ca-certificates
# distrust list (CVE-2026-111943: emSign ECC Root CA - G3 and AAA Certificate
# Services, packages/ca-certificates/distrust.txt). grpc 1.85's C core reads the
# OS trust store before it (DefaultSslRootStore::ComputePemRootCerts in
# src/core/credentials/transport/tls/ssl_utils.cc: config path, language
# override, then LoadSystemRootCerts, whose first Linux path is
# /etc/ssl/certs/ca-certificates.crt, and only then roots.pem). So the bundle
# matters only where there is no system store, and there it would silently
# trust a stale list. It is not shipped; ca-certificates is a runtime dep, so
# the system store is always present (pkgs#1547 review).
rm -f "$OUTPUT_DIR/usr/share/grpc/roots.pem"
rmdir "$OUTPUT_DIR/usr/share/grpc" 2>/dev/null || true
if [ -e "$OUTPUT_DIR/usr/share/grpc/roots.pem" ]; then
  echo "ERROR: grpc's private roots.pem is still in the output" >&2
  exit 1
fi
