#!/bin/bash
set -euo pipefail

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="-Wl,--build-id=none"

# The apps (nghttp, nghttpd, nghttpx, h2load) link libnghttp2 statically, from this same
# source, so this package ships no libnghttp2.so: it cannot collide with the nghttp2
# package's library in a closure, and its version does not have to move in lockstep.
#
# HTTP/3 goes through ngtcp2's OpenSSL backend (libngtcp2_crypto_ossl, the OpenSSL 3.5+
# QUIC TLS API) and nghttp3.
#
# Optional dependencies the build would pick up if present are off explicitly, so the
# result does not depend on what else is in the sandbox: libxml2 (nghttp -a asset
# fetching), jemalloc, brotli, systemd (nghttpx sd_notify), jansson (nghttp -r HAR
# output), libevent (examples), mruby, neverbleed, libbpf, wolfSSL (an alternative TLS
# backend; OpenSSL is the one used), and Python3, which is not a library: CMake looks
# for it only to install nghttpx's Python helper scripts, which are not shipped.
cmake -B build -G Ninja \
  -DCMAKE_INSTALL_PREFIX=/usr \
  -DCMAKE_INSTALL_LIBDIR=lib \
  -DCMAKE_BUILD_TYPE=Release \
  -DENABLE_APP=ON \
  -DENABLE_HTTP3=ON \
  -DENABLE_HPACK_TOOLS=OFF \
  -DENABLE_EXAMPLES=OFF \
  -DENABLE_FAILMALLOC=OFF \
  -DBUILD_SHARED_LIBS=OFF \
  -DBUILD_STATIC_LIBS=ON \
  -DBUILD_TESTING=OFF \
  -DWITH_LIBXML2=OFF \
  -DWITH_JEMALLOC=OFF \
  -DWITH_MRUBY=OFF \
  -DWITH_NEVERBLEED=OFF \
  -DWITH_LIBBPF=OFF \
  -DWITH_WOLFSSL=OFF \
  -DCMAKE_DISABLE_FIND_PACKAGE_Systemd=ON \
  -DCMAKE_DISABLE_FIND_PACKAGE_Jansson=ON \
  -DCMAKE_DISABLE_FIND_PACKAGE_Libevent=ON \
  -DCMAKE_DISABLE_FIND_PACKAGE_Libbrotlienc=ON \
  -DCMAKE_DISABLE_FIND_PACKAGE_Libbrotlidec=ON \
  -DCMAKE_DISABLE_FIND_PACKAGE_Python3=ON
ninja -C build
DESTDIR="$OUTPUT_DIR" ninja -C build install

# Keep the four programs and their man pages; the static library, headers, pkg-config
# and CMake files, docs and nghttpx's Python helper scripts are not part of this package.
keep=$(mktemp -d)
mkdir -p "$keep/bin" "$keep/man1"
for app in nghttp nghttpd nghttpx h2load; do
  mv "$OUTPUT_DIR/usr/bin/$app" "$keep/bin/"
  if [ -e "$OUTPUT_DIR/usr/share/man/man1/$app.1" ]; then
    mv "$OUTPUT_DIR/usr/share/man/man1/$app.1" "$keep/man1/"
  fi
done
rm -rf "${OUTPUT_DIR:?}/usr"
mkdir -p "$OUTPUT_DIR/usr/bin" "$OUTPUT_DIR/usr/share/man/man1"
mv "$keep"/bin/* "$OUTPUT_DIR/usr/bin/"
mv "$keep"/man1/* "$OUTPUT_DIR/usr/share/man/man1/" 2>/dev/null || true
rmdir "$OUTPUT_DIR/usr/share/man/man1" 2>/dev/null && rmdir "$OUTPUT_DIR/usr/share/man" "$OUTPUT_DIR/usr/share" || true

# Fail closed on a silently dropped feature: h2load must have HTTP/3 (ngtcp2 + its
# OpenSSL crypto backend + nghttp3) and libev, and must not need a shared libnghttp2.
needed=$(readelf -d "$OUTPUT_DIR/usr/bin/h2load")
for lib in libngtcp2.so libngtcp2_crypto_ossl.so libnghttp3.so libev.so libssl.so.4; do
  grep -q "NEEDED.*\[$lib" <<<"$needed" || { echo "h2load does not NEED $lib" >&2; exit 1; }
done
if grep -q 'NEEDED.*libnghttp2' <<<"$needed"; then
  echo "h2load NEEDs a shared libnghttp2" >&2; exit 1
fi
