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

# Trust the system CA store (/etc/ssl, from ca-certificates) instead of the
# Mozilla roots compiled into node, so a CA removed from ca-certificates
# (CVE-2026-111943, eMudhra) stops being trusted without a node rebuild.
# --openssl-use-def-ca-store defines NODE_OPENSSL_CERT_STORE, which makes
# `--use-openssl-ca` the default (configure.py, src/node_options.h at
# v26.12.1). With it, NewRootCertStore() in src/crypto/crypto_context.cc calls
# X509_STORE_set_default_paths() INSTEAD of adding the bundled roots: the store
# is replaced, not extended. Our openssl is built with --openssldir=/etc/ssl,
# so the default paths are /etc/ssl/cert.pem and /etc/ssl/certs ($SSL_CERT_FILE
# and $SSL_CERT_DIR override them, as in OpenSSL). NODE_EXTRA_CA_CERTS is still
# added on top. `--use-system-ca` is accepted but has no effect in this mode.
# tls.getCACertificates('default') still lists the bundled roots: lib/tls.js
# keys that list on the --use-openssl-ca flag, not on the store in use.
# Opt out with `--use-bundled-ca`, on the command line or in NODE_OPTIONS
# (kAllowedInEnvvar), which restores the compiled-in store.
./configure --prefix=/usr --openssl-use-def-ca-store \
    --with-intl=system-icu --shared-openssl --shared-zlib --shared-zstd --shared-sqlite --shared-libuv \
    --shared-nghttp2 --shared-nghttp3 --shared-ngtcp2 --shared-gtest  --shared-lief --shared-cares
make -j$(nproc)
make DESTDIR=$OUTPUT_DIR install

# The flag must have reached the binary: its --help marks the OpenSSL store as
# the default only when NODE_OPENSSL_CERT_STORE is defined (src/node_options.cc;
# tr undoes the help text's line folding).
"$OUTPUT_DIR/usr/bin/node" --help | tr -s ' \n' ' ' | grep -q "use OpenSSL's default CA store (default)" || {
  echo "ERROR: node was not built with --openssl-use-def-ca-store" >&2
  exit 1
}

# npm's compiled-in global prefix is /usr, which is the read-only package
# store at session time, so every `npm i -g` fails with ENOENT. Ship a
# builtin npmrc (npm's lowest-precedence config source, overridable by any
# user config) pointing globals at ~/.local, whose bin/ is already on the
# session PATH. See gominimal/inbox#559.
printf 'prefix=~/.local\n' > "$OUTPUT_DIR/usr/lib/node_modules/npm/npmrc"
