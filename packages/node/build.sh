#!/bin/sh
set -e

export CC=gcc

tar -xof "node-v${MINIMAL_ARG_VERSION}.tar.gz"
cd "node-v${MINIMAL_ARG_VERSION}"

# CVE-2026-111943 is fixed upstream (nodejs/node#66871 SPKI blocklist,
# #66877 NSS 3.131.1 roots). Fail the build if a future version regresses either.
grep -q "constexpr SpkiHash kBlockedSPKIs" src/crypto/crypto_context.cc &&
grep -q "InstallCertVerifyCallback(sc->ctx_.get());" src/crypto/crypto_context.cc || {
  echo "ERROR: upstream CVE-2026-111943 SPKI blocklist missing from src/crypto/crypto_context.cc" >&2
  exit 1
}
if grep -q "emSign ECC Root CA - G3" src/node_root_certs.h; then
  echo "ERROR: emSign ECC Root CA - G3 is back in src/node_root_certs.h (CVE-2026-111943)" >&2
  exit 1
fi

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
    --shared-nghttp2 --shared-nghttp3 --shared-ngtcp2 --shared-gtest  --shared-lief --shared-cares
make -j$(nproc)
make DESTDIR=$OUTPUT_DIR install

# npm's compiled-in global prefix is /usr, which is the read-only package
# store at session time, so every `npm i -g` fails with ENOENT. Ship a
# builtin npmrc (npm's lowest-precedence config source, overridable by any
# user config) pointing globals at ~/.local, whose bin/ is already on the
# session PATH. See gominimal/inbox#559.
printf 'prefix=~/.local\n' > "$OUTPUT_DIR/usr/lib/node_modules/npm/npmrc"
