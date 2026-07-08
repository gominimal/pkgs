#!/bin/sh
set -e

export CC=gcc

tar -xof "node-v${MINIMAL_ARG_VERSION}.tar.gz"
cd "node-v${MINIMAL_ARG_VERSION}"

# c-ares 1.34.7 (upstream PR #1060) changed ares_host_callback to take
# `const struct hostent *`. node hasn't adopted it yet, so QueryWrap::Callback's
# non-const `struct hostent* host` no longer matches the typedef and
# cares_wrap.cc fails to compile against the shared c-ares. Add the const — the
# callback body only forwards `host` to cares_wrap_hostent_cpy(dest, const src),
# so it's a safe minimal fix. Self-verifying: fail loudly if a future node bump
# changes the line (drop this patch once node ships a c-ares>=1.34.7 cares_wrap).
sed -i 's/^\(\s*\)struct hostent\* host) {$/\1const struct hostent* host) {/' src/cares_wrap.h
grep -q 'const struct hostent\* host) {' src/cares_wrap.h || {
  echo "ERROR: cares_wrap.h const-hostent patch did not apply (node source changed?)" >&2
  exit 1
}

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

./configure --prefix=/usr \
    --with-intl=system-icu --shared-openssl --shared-zlib --shared-zstd --shared-sqlite --shared-libuv \
    --shared-nghttp2 --shared-nghttp3 --shared-ngtcp2 --shared-gtest --shared-cares
    # Note: --shared-lief is omitted; that configure option was not added until Node.js v25.
make -j$(nproc)
make DESTDIR=$OUTPUT_DIR install
