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

BUILDROOT="$(pwd)"
# --- P0b offline harness ---
# curl/wget stubs exit non-zero: the build must fail if x.py or a build.rs tries the network.
# A real curl is in the rootfs (pulled in by cmake), so the stub's PATH precedence is asserted.
# git stub: local read-only verbs exit 1 (x.py's version stamp and a few vendored build.rs probe
# them and handle failure); network-capable and unknown verbs are tripwires.
STUBS="${BUILDROOT}/stubs"; mkdir -p "${STUBS}"
for t in curl wget; do
  cat > "${STUBS}/${t}" <<EOF
#!/bin/sh
echo "\$0 \$*" >> "${BUILDROOT}/NETWORK-TRIPWIRE"
echo "rust: FATAL — the build invoked '${t}', which must never happen offline" >&2
exit 1
EOF
  chmod 0755 "${STUBS}/${t}"
done

cat > "${STUBS}/git" <<EOF
#!/bin/sh
# Allowlist by subcommand: local read-only verbs exit 1 (git's out-of-repo behaviour, which x.py
# handles); network-capable verbs are tripwires; --version prints a stub.
if [ "\$1" = "--version" ]; then
  echo "git \$*" >> "${BUILDROOT}/GIT-LOCAL.log"; echo "git version 0.0.0-bedrock-stub"; exit 0
fi
case "\$1" in
  rev-parse|log|describe|symbolic-ref|show-ref|rev-list|cat-file|status|diff|show|name-rev|for-each-ref|update-index|config)
    echo "git \$*" >> "${BUILDROOT}/GIT-LOCAL.log"; exit 1 ;;   # local read-only; no network
  clone|fetch|pull|push|remote|ls-remote|submodule|archive|request-pull|send-pack|fetch-pack|upload-pack)
    echo "git \$*" >> "${BUILDROOT}/NETWORK-TRIPWIRE"
    echo "rust: FATAL — git NETWORK verb attempted: \$*" >&2; exit 1 ;;
  *)
    # unknown verb: default deny, so a new network path cannot slip through
    echo "git \$*" >> "${BUILDROOT}/NETWORK-TRIPWIRE"
    echo "rust: FATAL — git invoked with an un-allowlisted verb (default-deny): \$*" >&2; exit 1 ;;
esac
EOF
chmod 0755 "${STUBS}/git"

PATH="${STUBS}:${PATH}"; export PATH
[ "$(command -v curl)" = "${STUBS}/curl" ] || {
  echo "rust: FATAL the curl stub is NOT shadowing the real curl (packages/cmake pulls one in)." >&2
  echo "      command -v curl = $(command -v curl)" >&2; exit 1; }
[ "$(command -v git)" = "${STUBS}/git" ] || { echo "rust: FATAL the git stub is NOT first on PATH" >&2; exit 1; }

# --- P0c vendored submodule markers ---
# curl-sys and libssh2-sys build.rs check for a `.git` marker in their bundled submodule dir and,
# absent one (release tarballs ship none), run `git submodule update --init`, which the git stub
# fail-shuts.  An empty `.git` marker makes build.rs compile the sources shipped in the tarball.
# Checksum-safe: cargo's DirectorySource::verify checks only the files listed in
# .cargo-checksum.json, so an extra unlisted file is not detected.  Never edit a vendored file.
# The dirs are globbed (the -sys crate versions change per rung) and only populated ones are
# marked; marking an empty checkout would make the crate try to compile nothing.
# libgit2-sys is not marked: its guard keys on libgit2/src, which the tarball ships.
marked=0
for pat in "curl-sys-*/curl" "libssh2-sys-*/libssh2"; do
  # shellcheck disable=SC2231  # intentional glob on ${pat}
  for d in "${BUILDROOT}"/vendor/${pat}; do
    [ -d "${d}" ] || continue
    # a populated submodule dir has entries; an empty checkout has none
    n="$(find "${d}" -mindepth 1 -maxdepth 1 ! -name .git 2>/dev/null | head -1 | wc -l | tr -d ' ')"
    if [ "${n}" -lt 1 ]; then
      echo "rust SUBMOD: NOTE ${d#"${BUILDROOT}"/} ships no sources; NOT marking (expecting the pkg-config path)" >&2
      continue
    fi
    if [ ! -e "${d}/.git" ]; then
      : > "${d}/.git"
      marked=$((marked + 1))
      echo "rust SUBMOD: marked ${d#"${BUILDROOT}"/}/.git" >&2
    fi
  done
done
echo "rust SUBMOD: ${marked} vendored submodule marker(s) placed" >&2
# Diagnostic (non-fatal): whether pkg-config sees the system libs, so the log shows which path
# curl-sys/libssh2-sys will take if a marker was skipped.
for lib in libcurl libssh2; do
  if pkg-config --exists "${lib}" 2>/dev/null; then
    echo "rust SUBMOD: pkg-config sees ${lib} $(pkg-config --modversion "${lib}" 2>/dev/null)" >&2
  else
    echo "rust SUBMOD: NOTE pkg-config does NOT see ${lib} — the crate MUST use its vendored submodule (marker required above)" >&2
  fi
done

# bootstrap.toml sets `vendor = false` so bootstrap does not pass cargo --frozen (see there);
# force cargo offline so no path can reach the network.
export CARGO_NET_OFFLINE=true
export GIT_CEILING_DIRECTORIES="$(pwd)"
export GIT_CONFIG_NOSYSTEM=1
export GIT_TERMINAL_PROMPT=0

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

if [ -e "${BUILDROOT}/NETWORK-TRIPWIRE" ]; then
  echo "rust: FATAL a network fetch was attempted during the build:" >&2; cat "${BUILDROOT}/NETWORK-TRIPWIRE" >&2; exit 1
fi
rm $OUTPUT_DIR/usr/bin/rust-gdbgui
