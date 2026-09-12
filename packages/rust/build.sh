#!/bin/sh
set -ex

# ── STALE-STATE GUARD (2026-09-01): buildbot's res-server persists /build across rounds; a
# failed round's partial install in $OUTPUT_DIR would be swallowed by the capture globs.
# Start from an EMPTY output (build trees stay warm for the incremental ratchet).
[ -n "$OUTPUT_DIR" ] && [ -d "$OUTPUT_DIR" ] && find "$OUTPUT_DIR" -mindepth 1 -delete
mkdir -p "$OUTPUT_DIR"

export LIBSQLITE3_SYS_USE_PKG_CONFIG=1
export LIBSSH2_SYS_USE_PKG_CONFIG=1
case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir"
export LDFLAGS="-Wl,--build-id=none"
export CXXFLAGS="${CFLAGS}"

# ATTESTED stage0 (issue #17 — the ladder CLOSED, now on BOTH arches): the stage0
# rustc/cargo is the attested rustc-1.96.0 rung, NOT the old unattested seed-*.tar.gz and NOT
# x.py's stage0 download (that fallback is deleted; a missing stage0 is now FATAL on both
# arches).  amd64: the CS-attested rung build_dep, hydrated read-only at /usr/lib/rustc-1.96.0.
# arm64: the SEALED arm-ladder tarball Source (see build.ncl's BEDROCK ROOT note) — extract=true
# lands its topdir at ./rustc-1.96.0-aarch64 inside the source root ('rustc-1.96.0-aarch64'
# collides with nothing in the rustc-src tree, and an in-tree toolchain dir is already proven
# harmless by the stage0-clean copy below).  x.py uses it via bootstrap.toml [build] rustc/cargo
# and never downloads.  Runtime note (arm): the rung links libLLVM.so.21.1 shared ([llvm]
# link-shared, same shape as the amd64 rungs) — satisfied by this sandbox's llvm dep.
# See build.ncl's header for the chain and the LADDER EXTENSION note (1.97.1 pins 1.96.0).
if [ "$(uname -m)" = aarch64 ]; then
  STAGE0_PREFIX="$(pwd)/rustc-1.96.0-aarch64"
else
  STAGE0_PREFIX=/usr/lib/rustc-1.96.0
fi
SEED_RUSTC="${STAGE0_PREFIX}/bin/rustc"
SEED_CARGO="${STAGE0_PREFIX}/bin/cargo"
[ -x "$SEED_RUSTC" ] || { echo "rust: FATAL attested stage0 rustc missing at $SEED_RUSTC — the rustc-1.96.0 rung is THE anchor of this build" >&2; exit 1; }
[ -x "$SEED_CARGO" ] || { echo "rust: FATAL attested stage0 cargo missing at $SEED_CARGO" >&2; exit 1; }
# x.py parses the stage0 rustc's release (1.96.0) against src/stage0 (pins 1.96.0); equal-to-pin is
# accepted (check_stage0_version = same-or-one-minor) and sidesteps the tracked_env bootstrap skew.
S0V="$("$SEED_RUSTC" --version 2>&1 || true)"
echo "$S0V" | grep -qF "1.96.0" || { echo "rust: FATAL attested stage0 rustc --version = '$S0V', expected 1.96.0" >&2; exit 1; }
echo "rust stage0: CS-ATTESTED rustc-1.96.0 -> $S0V"

# ★ DROP THE STAGE0's STRAY rust-src.  The rustc-1.94.x rung was built `extended = true`, so its
# OutputData glob captured a bundled rust-src component (the stage0's OWN source, which uses
# the PRE-rename proc_macro::tracked_env API).  A filesystem locator PROVED x.py compiles THAT
# rustc_macros/symbols.rs (old API, line 263) instead of the fresh in-tree /build source (new
# proc_macro::tracked::env_var, line 262) → E0433 "could not find tracked_env".  The hydrated stage0
# is READ-ONLY so we can't rm rustc-src in place; copy the stage0 to a WRITABLE prefix and drop
# rust-src there, then point bootstrap.toml at the copy.  (Proper fix upstream: the rungs should
# build with extended=false or prune lib/rustlib/{rustc-src,src} from their OutputData.)
CLEAN0="$(pwd)/stage0-clean"
rm -rf "${CLEAN0}" 2>/dev/null || true
cp -a "${STAGE0_PREFIX}" "${CLEAN0}"
rm -rf "${CLEAN0}/lib/rustlib/rustc-src" "${CLEAN0}/lib/rustlib/src" 2>/dev/null || true
STAGE0_PREFIX="${CLEAN0}"
SEED_RUSTC="${STAGE0_PREFIX}/bin/rustc"
SEED_CARGO="${STAGE0_PREFIX}/bin/cargo"
echo "rust: writable stage0 copy WITHOUT rust-src -> ${STAGE0_PREFIX}"
echo "rust:   sysroot=$("$SEED_RUSTC" --print sysroot 2>&1)  |  remaining rustc-src symbols.rs on FS: $(find / -path '*rustlib/rustc-src*' -name symbols.rs 2>/dev/null | wc -l)"
[ -x "$SEED_RUSTC" ] || { echo "rust: FATAL copied stage0 rustc not executable" >&2; exit 1; }
# inject the stage0 override right after the [build] table header (order: rustc, cargo)
sed -i "/^\[build\]/a cargo = \"$SEED_CARGO\"" bootstrap.toml
sed -i "/^\[build\]/a rustc = \"$SEED_RUSTC\"" bootstrap.toml

# bootstrap.toml sets `vendor = false` so bootstrap does NOT pass cargo --frozen (see the comment
# there): the attested rung cargo (>=1.94 behavior) needs a deterministic offline Cargo.lock refresh from
# vendor/ that --frozen would forbid. Belt-and-suspenders: force cargo offline so no path can reach
# the network (there is no CS egress anyway; the .cargo/config.toml vendored-sources redirect keeps
# every crate local).
export CARGO_NET_OFFLINE=true

# ── Neutralize bootstrap's `Vendor` step ────────────────────────────────────────────────────────
# `x.py install` reaches bootstrap's Vendor step (vendor.rs), whose `is_default_step` is hardcoded
# `true` and whose `run()` shells out to `cargo vendor --sync src/tools/cargo/Cargo.toml …` against
# the tool workspaces, with root_dir = the source root (/build).  Offline in CS that dies with
# "failed to load lockfile for /build/src/tools/cargo" (the cargo tool submodule has no resolvable
# lock without network) and aborts install — AND it would clobber /build/vendor.  No [dist]/[build]
# config flag suppresses it (it is neither the src-tarball PlainSourceTarball vendor nor gated by
# dist_vendor for this default-step path).  We ship no vendored source, so gate the actual
# `cargo vendor` exec behind an env flag and return an empty vendor config.  This patches BUILD
# tooling only (bootstrap), never the rustc/cargo binaries we ship — x.py compiles bootstrap from
# this patched source on the next line, before it is used.
# Return from Vendor::run() BEFORE the cargo command is constructed.  bootstrap's `command()` wraps
# a "drop bomb" (build_helper drop_bomb) that panics if the Command is built but never executed, so
# we cannot merely skip the exec — we must not construct it.  Early-return an empty VendorOutput;
# `self`/`builder` stay used on the normal (env-unset) path so there are no unused/unreachable warns.
VENDOR_RS=src/bootstrap/src/core/build_steps/vendor.rs
grep -q 'BOOTSTRAP_SKIP_VENDOR' "$VENDOR_RS" || {
  sed -i 's|let _guard = builder.group(&format!("Vendoring sources|if std::env::var_os("BOOTSTRAP_SKIP_VENDOR").is_some() { return VendorOutput { config: String::new(), config_library: String::new() }; }\n        let _guard = builder.group(\&format!("Vendoring sources|' "$VENDOR_RS"
  grep -q 'BOOTSTRAP_SKIP_VENDOR' "$VENDOR_RS" || { echo "rust: FATAL vendor.rs early-return patch did not apply (upstream changed the Vendoring-sources group line)" >&2; exit 1; }
}
export BOOTSTRAP_SKIP_VENDOR=1

./x.py build

# Install EXPLICIT components, NOT a bare `./x.py install`.  A bare install installs the default set,
# which includes the `src` (rust-src) component → dist::Src → PlainSourceTarball → a `cargo vendor
# --sync src/tools/cargo/Cargo.toml …` that fails offline ("failed to load lockfile", no CS egress) and
# aborts the whole install.  The [dist] vendor=false / src-tarball=false + [build] tools flags did NOT
# suppress it (the Src step is reached regardless during a full install).  Naming components makes
# x.py run ONLY these steps — the Src step's `should_run` is `run.path("src")`, which none of these
# match, so PlainSourceTarball/Vendor never runs.  This is the toolchain: std + compiler +
# cargo/clippy/rustfmt/rust-analyzer.  (rust-src is shipped too, but via the direct copy below,
# never via the src install step — a bundled rust-src in a rustc RUNG is what polluted x.py
# with the pre-rename tracked_env source; the final rust is not a rung stage0.)
DESTDIR=$OUTPUT_DIR ./x.py install library/std compiler/rustc cargo clippy rustfmt rust-analyzer

# rust-src for -Zbuild-std consumers (rust-arm-embedded reads {sysroot}/lib/rustlib/src/rust/
# library/ — buildbot arm64 caught its absence once the flip made THIS recipe the shipping
# rust; the old bindists bundled rust-src).  Installed by DIRECT COPY of this build's own
# library tree (functionally the rust-src component: library/** including its Cargo.lock and
# the vendored stdarch/backtrace subtrees), deliberately NOT via `x.py install src` — that
# path reaches PlainSourceTarball/Vendor exactly as the note above explains.  The rung
# stage0s still ship NO rustlib/src (the CLEAN0 lesson); shipping it in the FINAL rust is
# fine because nothing consumes packages/rust as a bootstrap stage0.
mkdir -p "$OUTPUT_DIR/usr/lib/rustlib/src/rust"
cp -a library "$OUTPUT_DIR/usr/lib/rustlib/src/rust/library"

rm $OUTPUT_DIR/usr/bin/rust-gdbgui
