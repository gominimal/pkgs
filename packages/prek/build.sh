#!/bin/sh
set -ex
export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc"

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

cargo build --release

mkdir -p $OUTPUT_DIR/usr/bin
ls -lah target/release
cp target/release/prek $OUTPUT_DIR/usr/bin
