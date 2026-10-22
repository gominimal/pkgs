#!/bin/sh
set -ex
export CARGO_INCREMENTAL=0
export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc"

# yazi 26.8+ embeds a build-time git SHA: yazi-version/build.rs runs vergen,
# which needs a `.git` dir + `git` binary. Our hermetic build is a tarball
# extract with neither, so vergen warns "Unable to set VERGEN_GIT_SHA" and emits
# nothing — then `env!("VERGEN_GIT_SHA")` in yazi-version/src/lib.rs is a
# compile-time hard error. Provide it in the environment (env! reads the ambient
# process env when the build script sets nothing). Fixed, not the real commit,
# so two builds stay byte-identical; `yazi --version` reports the release.
export VERGEN_GIT_SHA="v${MINIMAL_ARG_VERSION}"

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

cargo build --release --locked

mkdir -p $OUTPUT_DIR/usr/bin
cp target/release/yazi $OUTPUT_DIR/usr/bin
