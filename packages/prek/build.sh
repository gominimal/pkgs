#!/bin/sh
set -ex
export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc"

# Security floor (data/security_floors.toml): kept by pkgmgr when the lock
# patch it guarded became unnecessary. No pre-fix version may be locked.
if grep -A1 -E '^name = "(rustls-webpki|webpki-roots|webpki-root-certs)"$' Cargo.lock |
  grep -qE '^version = "(0[.]103[.]([0-9]|1[0-5])|1[.]0[.][0-9])"$'; then
  echo "ERROR: a pre-CVE-2026-111943 rustls-webpki / webpki-roots is still in Cargo.lock" >&2
  exit 1
fi

# Trust the system CA store (/etc/ssl/certs) by default instead of the
# webpki-root-certs list compiled into prek, so a fix to ca-certificates
# reaches prek's toolchain downloads without a rebuild (CVE-2026-111943,
# eMudhra). Upstream only does this when PREK_NATIVE_TLS=1; patch the unset
# case to "on when the system bundle exists", since native TLS with no
# ca-certificates installed would trust nothing. An explicit PREK_NATIVE_TLS
# (0 or 1) still wins. The grep makes an upstream rewrite of this code fail
# the build instead of silently dropping the default.
sed -i 's|^        \.unwrap_or(false);$|        .unwrap_or_else(\|\| std::path::Path::new("/etc/ssl/certs/ca-certificates.crt").is_file()); // minimal: system CA store by default|' crates/prek/src/http.rs
grep -q 'minimal: system CA store by default' crates/prek/src/http.rs || { echo "ERROR: prek PREK_NATIVE_TLS default patch did not apply; crates/prek/src/http.rs changed upstream" >&2; exit 1; }

cargo build --locked --release

mkdir -p $OUTPUT_DIR/usr/bin
ls -lah target/release
cp target/release/prek $OUTPUT_DIR/usr/bin
