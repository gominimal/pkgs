#!/bin/sh
set -e

export CC=gcc

tar -xof "node-${MINIMAL_ARG_VERSION}.tar.gz"
cd "node-${MINIMAL_ARG_VERSION}"

# Applied by name, never a glob, so a patch that stops being fetched fails the
# build instead of being silently skipped (same convention as packages/libssh2).
patch -Np1 -i "../lief-1.x-macho-section-ctor.patch"

# Prove it landed: `patch` can exit 0 on an already-applied hunk, so a zero
# exit is necessary but not sufficient.
grep -q "LIEF::MachO::Section::create(section_name, data)" src/node_sea_bin.cc || {
  echo "ERROR: LIEF 1.x Section patch did not land in src/node_sea_bin.cc" >&2
  exit 1
}

# CVE-2026-111943 (compromised eMudhra intermediate keys, Mozilla bug 2083449).
# Backports of nodejs/node#66871 (SPKI blocklist in TLS chain verification) and
# the root-store half of nodejs/node#66877 (drop the emSign roots NSS 3.131.1
# removed). Both merged to node main on 2026-10-20 and are NOT in a release yet;
# see each patch header for the deviations from upstream and when to drop them.
#
# The bundled root store is what `tls` trusts by default (we do not configure
# --use-openssl-ca), so the ca-certificates fix does not reach it; and the
# blocklist is needed even with the roots gone, because a chain through a
# compromised key also verifies against any OTHER store that still carries a
# path to it (system store, a caller's `ca`, the Sectigo cross-sign).
patch -Np1 -i "../cve-2026-111943-tls-spki-blocklist.patch"
patch -Np1 -i "../cve-2026-111943-drop-emsign-roots.patch"

# Prove both landed (patch can exit 0 on an already-applied hunk): the
# blocklist table, its install on every SecureContext, and the root gone.
grep -q "constexpr SpkiHash kBlockedSPKIs" src/crypto/crypto_context.cc &&
grep -q "InstallCertVerifyCallback(sc->ctx_.get());" src/crypto/crypto_context.cc || {
  echo "ERROR: CVE-2026-111943 SPKI blocklist patch did not land in src/crypto/crypto_context.cc" >&2
  exit 1
}
if grep -q "emSign ECC Root CA - G3" src/node_root_certs.h; then
  echo "ERROR: CVE-2026-111943 root removal did not land in src/node_root_certs.h" >&2
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
