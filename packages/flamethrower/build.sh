#!/bin/bash
set -euo pipefail

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export CXXFLAGS="$CFLAGS"
export LDFLAGS="-Wl,--build-id=none"
export ARFLAGS=Drc

# Newer cpp-httplib over the vendored 0.28.0 (see build.ncl), fail-closed on the version.
hv="$MINIMAL_ARG_HTTPLIB_VERSION"
tar -xof "v$hv.tar.gz" "cpp-httplib-$hv/httplib.h" "cpp-httplib-$hv/LICENSE"
install -m644 "cpp-httplib-$hv/httplib.h" 3rd/cpp-httplib/include/httplib.h
install -m644 "cpp-httplib-$hv/LICENSE" 3rd/cpp-httplib/LICENSE
grep -qx "#define CPPHTTPLIB_VERSION \"$hv\"" 3rd/cpp-httplib/include/httplib.h || {
  echo "ERROR: 3rd/cpp-httplib/include/httplib.h is not cpp-httplib $hv" >&2
  exit 1
}

# The bundled libraries (3rd/) are static archives linked into `flame`; meson writes
# deterministic archives itself. `doh` is upstream's default; set explicitly so a missing
# nghttp2 fails here instead of building without DoH.
meson setup build \
  --prefix=/usr \
  --buildtype=release \
  -Ddoh=true
ninja -C build -j"$(nproc)"
DESTDIR="$OUTPUT_DIR" meson install -C build --no-rebuild

install -Dm644 man/flame.1 "$OUTPUT_DIR/usr/share/man/man1/flame.1"

lic="$OUTPUT_DIR/usr/share/licenses/flamethrower"
install -Dm644 LICENSE "$lic/LICENSE"
install -Dm644 3rd/uvw/LICENSE "$lic/uvw/LICENSE"
install -Dm644 3rd/cpp-httplib/LICENSE "$lic/cpp-httplib/LICENSE"
install -Dm644 3rd/json/LICENSE.MIT "$lic/json/LICENSE.MIT"
install -Dm644 3rd/urlparse/COPYING "$lic/urlparse/COPYING"
install -Dm644 3rd/docopt.cpp/LICENSE-MIT "$lic/docopt.cpp/LICENSE-MIT"
install -Dm644 3rd/docopt.cpp/LICENSE-Boost-1.0 "$lic/docopt.cpp/LICENSE-Boost-1.0"
install -Dm644 3rd/cpp-base64/LICENSE "$lic/cpp-base64/LICENSE"

# Fail closed on an unexpected library: runtime_deps is glibc, libstdc++/libgcc_s, libuv,
# ldns, gnutls and nghttp2.
needed=$(readelf -d "$OUTPUT_DIR/usr/bin/flame" | sed -n 's/.*Shared library: \[\(.*\)\]/\1/p')
echo "$needed"
if grep -vxE 'lib(c|m)\.so\.6|libstdc\+\+\.so\.6|libgcc_s\.so\.1|libuv\.so\.1|libldns\.so\.3|libgnutls\.so\.30|libnghttp2\.so\.14|ld-linux-(x86-64|aarch64)\.so\.[12]' <<<"$needed"; then
  echo "ERROR: flame NEEDs a library outside its runtime_deps (above)" >&2
  exit 1
fi
for lib in libldns.so.3 libuv.so.1 libgnutls.so.30 libnghttp2.so.14; do
  grep -qx "$lib" <<<"$needed" || { echo "ERROR: flame does not NEED $lib" >&2; exit 1; }
done

# Logged so two builds can be compared (reproducibility).
sha256sum "$OUTPUT_DIR/usr/bin/flame"
