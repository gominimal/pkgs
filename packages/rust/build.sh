#!/bin/sh
set -ex

# Start from an empty $OUTPUT_DIR: a persistent build root could leave a stale partial install
# that the output globs would capture.
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

# stage0 = the rustc-1.96.0 rung (1.97.1's src/stage0 pins 1.96.0).  amd64: the rung build_dep,
# hydrated read-only at /usr/lib/rustc-1.96.0.  arm64: the sha-pinned tarball Source from
# build.ncl, extracted to ./rustc-1.96.0-aarch64 inside the source root.  The stage0 is injected
# into bootstrap.toml [build] rustc/cargo below; x.py never downloads one, and a missing stage0
# is fatal.
if [ "$(uname -m)" = aarch64 ]; then
  STAGE0_PREFIX="$(pwd)/rustc-1.96.0-aarch64"
else
  STAGE0_PREFIX=/usr/lib/rustc-1.96.0
fi
SEED_RUSTC="${STAGE0_PREFIX}/bin/rustc"
SEED_CARGO="${STAGE0_PREFIX}/bin/cargo"
[ -x "$SEED_RUSTC" ] || { echo "rust: FATAL stage0 rustc missing at $SEED_RUSTC — the rustc-1.96.0 package is required" >&2; exit 1; }
[ -x "$SEED_CARGO" ] || { echo "rust: FATAL stage0 cargo missing at $SEED_CARGO" >&2; exit 1; }
# x.py checks the stage0 release against the src/stage0 pin; equal to the pin is accepted.
S0V="$("$SEED_RUSTC" --version 2>&1 || true)"
echo "$S0V" | grep -qF "1.96.0" || { echo "rust: FATAL stage0 rustc --version = '$S0V', expected 1.96.0" >&2; exit 1; }
echo "rust stage0: rustc-1.96.0 -> $S0V"

# Drop the stage0's bundled rust-src: x.py compiles that stale copy of rustc_macros instead of the
# in-tree source (E0433 on the renamed proc_macro::tracked_env API).  The hydrated stage0 is
# read-only, so copy it to a writable prefix, remove rust-src there and use the copy.
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

# bootstrap.toml sets `vendor = false` so bootstrap does not pass cargo --frozen (see there);
# force cargo offline so no path can reach the network.
export CARGO_NET_OFFLINE=true

# --- neutralize bootstrap's Vendor step ---
# `x.py install` runs the Vendor step (vendor.rs) unconditionally; it shells out to
# `cargo vendor --sync src/tools/cargo/Cargo.toml`, which fails offline and would clobber vendor/.
# No config flag suppresses it, so gate it behind an env flag.  The early return must come before
# the Command is constructed: bootstrap's command() carries a drop bomb that panics if a built
# Command is never executed.  Only build tooling is patched, never the shipped rustc/cargo.
VENDOR_RS=src/bootstrap/src/core/build_steps/vendor.rs
grep -q 'BOOTSTRAP_SKIP_VENDOR' "$VENDOR_RS" || {
  sed -i 's|let _guard = builder.group(&format!("Vendoring sources|if std::env::var_os("BOOTSTRAP_SKIP_VENDOR").is_some() { return VendorOutput { config: String::new(), config_library: String::new() }; }\n        let _guard = builder.group(\&format!("Vendoring sources|' "$VENDOR_RS"
  grep -q 'BOOTSTRAP_SKIP_VENDOR' "$VENDOR_RS" || { echo "rust: FATAL vendor.rs early-return patch did not apply (upstream changed the Vendoring-sources group line)" >&2; exit 1; }
}
export BOOTSTRAP_SKIP_VENDOR=1

./x.py build

# Install explicit components rather than a bare `./x.py install`: the default set includes the
# `src` component, whose dist::Src step runs the same offline-hostile `cargo vendor`.  None of
# these paths match the Src step's should_run, so it never runs.
DESTDIR=$OUTPUT_DIR ./x.py install library/std compiler/rustc cargo clippy rustfmt rust-analyzer

# rust-src for -Zbuild-std consumers ({sysroot}/lib/rustlib/src/rust/library): copied from this
# build's own library tree rather than installed via `x.py install src` (see above).
mkdir -p "$OUTPUT_DIR/usr/lib/rustlib/src/rust"
cp -a library "$OUTPUT_DIR/usr/lib/rustlib/src/rust/library"

rm $OUTPUT_DIR/usr/bin/rust-gdbgui
