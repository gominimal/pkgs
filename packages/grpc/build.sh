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

# SECURITY, CVE-2026-111943 (eMudhra key compromise; GHSA-rjr3-9pq9-5wm4):
# grpc's bundled root store, installed as usr/share/grpc/roots.pem and read
# when no system or env roots are configured, still trusts emSign Root CA - G1
# (eMudhra). Drop it, as ca-certificates did on 2026-10-20. Each entry runs
# from its "# <sha256>" line to the next one; some entries have a blank line
# between the text dump and the PEM, so a paragraph split would orphan a PEM.
ROOTS="$OUTPUT_DIR/usr/share/grpc/roots.pem"
before=$(grep -c 'BEGIN CERTIFICATE' "$ROOTS")
awk '/^# [0-9a-f]+$/ && length($0) == 66 { if (buf !~ /eMudhra/) printf "%s", buf; buf = "" }
     { buf = buf $0 "\n" }
     END { if (buf !~ /eMudhra/) printf "%s", buf }' "$ROOTS" > "$ROOTS.tmp"
mv "$ROOTS.tmp" "$ROOTS"
after=$(grep -c 'BEGIN CERTIFICATE' "$ROOTS")
if grep -qi -e emudhra -e emsign "$ROOTS"; then
  echo "ERROR: roots.pem still names eMudhra/emSign" >&2; exit 1
fi
if [ "$after" -ne "$(grep -cE '^# [0-9a-f]{64}$' "$ROOTS")" ] || [ "$after" -ne $((before - 1)) ]; then
  echo "ERROR: roots.pem filter removed $((before - after)) certs (want 1); grpc's file changed, re-check" >&2; exit 1
fi
