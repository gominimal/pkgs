#!/bin/sh
set -ex

tar -xof uv-${MINIMAL_ARG_VERSION}.tar.gz
cd uv-${MINIMAL_ARG_VERSION}

export CC=gcc
export LD=gcc
export RUSTFLAGS="-C linker=gcc"

# >>> pkgmgr lock-patch (generated; regenerate with `pkgmgr lock-patch uv`, never edit)
# security-floors-lock.patch is a cargo-resolved delta against upstream's Cargo.lock; it is
# only valid for the exact lock it was generated from.
echo "968afc762afac196109a89b7546ef2346ecca377208a70686d37a61fecc08d0a  Cargo.lock" | sha256sum -c --status - || {
  echo "ERROR: upstream Cargo.lock changed; run: pkgmgr lock-patch uv" >&2
  exit 1
}
patch -Np1 -i ../security-floors-lock.patch
# Security floors (version-agnostic): no locked version below a fixed release.
if grep -A1 '^name = "ctutils"$' Cargo.lock | grep -qE '^version = "0[.]4[.](([0-3])([-+][^"]*)?|4-[^"]*)"$'; then
  echo "ERROR: ctutils below its security floor 0.4.4 is in Cargo.lock (RUSTSEC-2026-0385)" >&2
  exit 1
fi
if grep -A1 '^name = "event-listener"$' Cargo.lock | grep -qE '^version = "5[.]4[.](([0-1])([-+][^"]*)?|2-[^"]*)"$'; then
  echo "ERROR: event-listener below its security floor 5.4.2 is in Cargo.lock (RUSTSEC-2026-0221)" >&2
  exit 1
fi
if grep -A1 '^name = "memmap2"$' Cargo.lock | grep -qE '^version = "0[.]9[.](([0-9]|10)([-+][^"]*)?|11-[^"]*)"$'; then
  echo "ERROR: memmap2 below its security floor 0.9.11 is in Cargo.lock (RUSTSEC-2026-0186)" >&2
  exit 1
fi
if grep -A1 '^name = "rustls"$' Cargo.lock | grep -qE '^version = "0[.]23[.](([0-9]|[1-3][0-9]|4[0-5])([-+][^"]*)?|46-[^"]*)"$'; then
  echo "ERROR: rustls below its security floor 0.23.46 is in Cargo.lock (RUSTSEC-2026-0346, RUSTSEC-2026-0347, RUSTSEC-2026-0348, RUSTSEC-2026-0349)" >&2
  exit 1
fi
if grep -A1 '^name = "tokio"$' Cargo.lock | grep -qE '^version = "1[.]53[.](([0-2])([-+][^"]*)?|3-[^"]*)"$'; then
  echo "ERROR: tokio below its security floor 1.53.3 is in Cargo.lock (RUSTSEC-2026-0386)" >&2
  exit 1
fi
if grep -A1 '^name = "zstd"$' Cargo.lock | grep -qE '^version = "0[.]14[.](([0-2])([-+][^"]*)?|3-[^"]*)"$'; then
  echo "ERROR: zstd below its security floor 0.14.3 is in Cargo.lock (RUSTSEC-2026-0391)" >&2
  exit 1
fi
if grep -A1 '^name = "zstd-safe"$' Cargo.lock | grep -qE '^version = "(8[.]2[.]0-[^"]*|8[.]0[.][0-9]+([-+][^"]*)?)"$'; then
  echo "ERROR: zstd-safe below its security floor 8.2.0 is in Cargo.lock (RUSTSEC-2026-0395, RUSTSEC-2026-0396, RUSTSEC-2026-0397, RUSTSEC-2026-0398, RUSTSEC-2026-0399, RUSTSEC-2026-0400, RUSTSEC-2026-0401, RUSTSEC-2026-0402, RUSTSEC-2026-0403, RUSTSEC-2026-0404, RUSTSEC-2026-0405, RUSTSEC-2026-0406)" >&2
  exit 1
fi
if grep -A1 '^name = "zstd-sys"$' Cargo.lock | grep -qE '^version = "2[.]1[.](([0-1])([-+][^"]*)?|2-[^"]*)"$'; then
  echo "ERROR: zstd-sys below its security floor 2.1.2 is in Cargo.lock (RUSTSEC-2026-0410)" >&2
  exit 1
fi
# <<< pkgmgr lock-patch

# Security floor (data/security_floors.toml): kept by pkgmgr when the lock
# patch it guarded became unnecessary. No pre-fix version may be locked.
if grep -A1 -E '^name = "(rustls-webpki|webpki-roots|webpki-root-certs)"$' Cargo.lock |
  grep -qE '^version = "(0[.]103[.]([0-9]|1[0-5])|1[.]0[.][0-9])"$'; then
  echo "ERROR: a pre-CVE-2026-111943 rustls-webpki / webpki-roots is still in Cargo.lock" >&2
  exit 1
fi

cargo build --locked --release

mkdir -p $OUTPUT_DIR/usr/bin
cp target/release/uv $OUTPUT_DIR/usr/bin/uv

# System-level uv.toml: trust the system CA store (/etc/ssl/certs) instead of
# the Mozilla roots compiled into uv, so a fix to ca-certificates reaches uv
# without a rebuild (CVE-2026-111943, eMudhra). uv reads /etc/uv/uv.toml as
# its lowest-precedence config (below the user's ~/.config/uv/uv.toml and the
# project's uv.toml). To opt out: --no-system-certs, `system-certs = false` in
# a user or project uv.toml, or UV_NO_SYSTEM_CONFIG=1. UV_SYSTEM_CERTS=false
# does NOT opt out: uv only lets that variable turn the setting on.
# `system-certs` is uv's name since 0.11 (`native-tls` is the deprecated one).
# With it set, uv hands certificate checks to rustls-platform-verifier, which
# on Linux trusts only the system store (/etc/ssl/certs); needs.internet brings
# ca-certificates into every environment uv lands in.
mkdir -p "$OUTPUT_DIR/etc/uv"
cat > "$OUTPUT_DIR/etc/uv/uv.toml" <<'TOML'
# Shipped by Minimal's uv package. Trust the system CA store, so CA
# removals in ca-certificates apply without rebuilding uv.
system-certs = true
TOML
