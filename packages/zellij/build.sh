#!/bin/sh
set -ex
export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc"
export OPENSSL_DIR=/usr
export OPENSSL_NO_VENDOR=1

# CVE-2026-111943: move upstream's Cargo.lock to rustls-webpki 0.103.16 and
# webpki-roots / webpki-root-certs 1.0.10 (see build.ncl). Applied by name so a
# missing or stale patch fails the build.
patch -Np1 -i ./cve-2026-111943-webpki-lock.patch
# Prove it landed, fail-closed: the fixed verifier is locked, and no pre-fix
# rustls-webpki 0.103.x or webpki-roots / webpki-root-certs 1.0.x remains.
grep -A1 '^name = "rustls-webpki"$' Cargo.lock | grep -q '^version = "0.103.16"$' || {
  echo "ERROR: rustls-webpki 0.103.16 is not in Cargo.lock (CVE-2026-111943)" >&2
  exit 1
}
if grep -A1 -E '^name = "(rustls-webpki|webpki-roots|webpki-root-certs)"$' Cargo.lock |
  grep -qE '^version = "(0[.]103[.]([0-9]|1[0-5])|1[.]0[.][0-9])"$'; then
  echo "ERROR: a pre-CVE-2026-111943 rustls-webpki / webpki-roots is still in Cargo.lock" >&2
  exit 1
fi

# OpenSSL 4: openssl-sys 0.9.117 (see build.ncl). Fail closed if the bump
# did not land.
patch -Np1 -i ./openssl-4-openssl-sys-lock.patch
grep -A1 '^name = "openssl-sys"$' Cargo.lock | grep -q '^version = "0.9.117"$' || {
  echo "ERROR: openssl-sys 0.9.117 is not in Cargo.lock (OpenSSL 4)" >&2
  exit 1
}

# OpenSSL 4: curl-sys's bundled curl 8.4.0 reads OpenSSL's now-opaque
# ASN1_INTEGER and fails on 4.x, so zellij must link the system libcurl.
# Two things forced the bundled copy: the default `vendored_curl` feature
# (isahc/static-curl), dropped here, and isahc's `http2` feature, because
# curl-sys only accepts a system curl that reports HTTP2 (ours has no nghttp2).
# The patch removes `http2` (Cargo.toml + the matching Cargo.lock edit).
patch -Np1 -i ./openssl-4-no-isahc-http2.patch
grep -q 'features = \["text-decoding"\]' Cargo.toml || {
  echo "ERROR: isahc http2 removal did not apply" >&2
  exit 1
}
cargo build --locked --release --no-default-features --features plugins_from_target,web_server_capability
readelf -d target/release/zellij | grep -q 'NEEDED.*libcurl\.so' || {
  echo "ERROR: zellij does not link the system libcurl (vendored curl crept back in?)" >&2
  exit 1
}

mkdir -p $OUTPUT_DIR/usr/bin
install -m 755 target/release/zellij $OUTPUT_DIR/usr/bin/zellij
