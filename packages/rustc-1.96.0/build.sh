#!/bin/sh
# build.sh — builds rustc ${VERSION} from the rustc-<v>-src tarball with the previous rung's rustc
# as x.py's stage0 (a build_dep at /usr/lib/rustc-<stage0>), fully offline, installed to the
# private prefix /usr/lib/rustc-<v>.  See build.ncl.
# phases: P0 preconditions, P0b offline stubs, P0c submodule markers, P1 bootstrap.toml,
#         P2 x.py build, P3 install, P4 path sweep, P5 gates, P6 seal.
# VERSION and STAGE0_VERSION are the only per-rung values; STAGE0_PREFIX derives from them.
set -ex

# Start from an empty OUTPUT_DIR: a failed earlier round's partial install would otherwise be
# swallowed by the capture globs.
if [ -n "$OUTPUT_DIR" ] && [ -d "$OUTPUT_DIR" ]; then
  for _e in "$OUTPUT_DIR"/* "$OUTPUT_DIR"/.[!.]* "$OUTPUT_DIR"/..?*; do [ -e "$_e" ] || [ -L "$_e" ] && rm -r "$_e"; done
fi
mkdir -p "$OUTPUT_DIR"

VERSION=1.96.0
STAGE0_VERSION=1.95.0
# The stage0 build_dep supplies the rustc for the host arch; MARCH dispatches on it below too.
case "$(uname -m)" in
  x86_64)  TRIPLE=x86_64-unknown-linux-gnu ;;
  aarch64) TRIPLE=aarch64-unknown-linux-gnu ;;
  *) echo "rustc: unsupported arch $(uname -m)" >&2; exit 1 ;;
esac

BUILDROOT="$(pwd)"
PREFIX="/usr/lib/rustc-${VERSION}"        # private versioned prefix, not /usr/bin
DST="${OUTPUT_DIR}${PREFIX}"              # staged install location = ${DESTDIR}${prefix}

# stage0 = the previous rung's installed prefix, consumed as a build_dep.  The 1.90.0 rung is an
# mrustc build installed at /usr/lib/mrustc-rust-1.90.0; every later rung installs at /usr/lib/rustc-<v>.
case "${STAGE0_VERSION}" in
  1.90.0) STAGE0_PREFIX="/usr/lib/mrustc-rust-${STAGE0_VERSION}" ;;  # the mrustc rung
  *)      STAGE0_PREFIX="/usr/lib/rustc-${STAGE0_VERSION}" ;;         # all later rungs
esac
STAGE0_RUSTC="${STAGE0_PREFIX}/bin/rustc"  # a POSIX-sh wrapper for 1.90.0, a real ELF later; both resolve --print sysroot in place
STAGE0_CARGO="${STAGE0_PREFIX}/bin/cargo"

# A stage0 that ships a bundled rust-src (lib/rustlib/rustc-src) makes x.py resolve rustc_macros
# through it and compile pre-rename proc_macro::tracked_env code that the stage0's libproc_macro
# no longer exports (E0433).  Bootstrap from a copy with that source stripped.
CLEAN0="${BUILDROOT}/stage0-clean"
rm -rf "${CLEAN0}" 2>/dev/null || true
cp -a "${STAGE0_PREFIX}" "${CLEAN0}"
rm -rf "${CLEAN0}/lib/rustlib/rustc-src" "${CLEAN0}/lib/rustlib/src" 2>/dev/null || true
STAGE0_PREFIX="${CLEAN0}"
STAGE0_RUSTC="${STAGE0_PREFIX}/bin/rustc"
STAGE0_CARGO="${STAGE0_PREFIX}/bin/cargo"

JOBS="$(nproc 2>/dev/null || echo 4)"

case "$(uname -m)" in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
# Same CFLAGS as packages/rust; -ffile-prefix-map keeps the build root out of C debug info.
export CFLAGS="${MARCH} -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=${BUILDROOT}=/builddir"
export CXXFLAGS="${CFLAGS}"
export LDFLAGS="-Wl,--build-id=none"
export LIBSQLITE3_SYS_USE_PKG_CONFIG=1
export LIBSSH2_SYS_USE_PKG_CONFIG=1

# --- P0 preconditions: tools, LLVM major, the stage0 itself, the extracted source ---
for t in clang clang++ llvm-config ar ranlib python3 pkg-config cmake \
         find sed grep tar xz sha256sum readelf; do
  command -v "${t}" >/dev/null 2>&1 || { echo "rustc: '${t}' not on PATH" >&2; exit 1; }
done

LLVMVER="$(llvm-config --version 2>/dev/null || echo unknown)"
case "${LLVMVER}" in
  21.*) : ;;
  *) echo "rustc: llvm-config --version = '${LLVMVER}', expected 21.x (rustc ${VERSION} targets LLVM 21)." >&2
     echo "            A too-new/too-old external LLVM hard-errors at x.py configure.  Refusing." >&2
     exit 1 ;;
esac

# stage0 binaries from the previous rung
[ -x "${STAGE0_RUSTC}" ] || { echo "rustc: FATAL stage0 rustc missing at ${STAGE0_RUSTC} — the stage0 package is required" >&2; exit 1; }
[ -x "${STAGE0_CARGO}" ] || { echo "rustc: FATAL stage0 cargo missing at ${STAGE0_CARGO}" >&2; exit 1; }

# The 1.90.0 stage0 reports `1.90.0-stable-mrustc`; later stage0s report a bare version, so this
# is a substring match.  x.py's own stage0-version check runs early and fails fast anyway.
S0V="$("${STAGE0_RUSTC}" --version 2>&1 || true)"
echo "${S0V}" | grep -qF "${STAGE0_VERSION}" || {
  echo "rustc: FATAL stage0 rustc --version = '${S0V}', expected to contain ${STAGE0_VERSION}" >&2; exit 1; }
# --print sysroot must resolve to the stage0 prefix: proves the stage0 runs in place and that its
# std is where x.py will look for it.
S0SR="$("${STAGE0_RUSTC}" --print sysroot 2>&1 || true)"
[ "${S0SR}" = "${STAGE0_PREFIX}" ] || {
  echo "rustc: FATAL stage0 rustc --print sysroot = '${S0SR}', expected ${STAGE0_PREFIX}" >&2; exit 1; }
[ -d "${STAGE0_PREFIX}/lib/rustlib/${TRIPLE}/lib" ] || {
  echo "rustc: FATAL stage0 std sysroot missing at ${STAGE0_PREFIX}/lib/rustlib/${TRIPLE}/lib" >&2; exit 1; }
"${STAGE0_CARGO}" --version >/dev/null 2>&1 || { echo "rustc: FATAL stage0 cargo did not execute" >&2; exit 1; }
echo "rustc STAGE0: stage0 OK — ${S0V} (sysroot ${S0SR})" >&2

# --- the extracted source must be the right one ---
# extract=true: the harness already unpacked and sha-verified the tarball, so assert the tree
# identity (version and bootstrap pairing) instead of re-hashing.
[ -f "${BUILDROOT}/x.py" ]                || { echo "rustc: FATAL x.py absent — source not extracted to build root" >&2; exit 1; }
[ -d "${BUILDROOT}/vendor" ]              || { echo "rustc: FATAL vendor/ absent — source is not the self-contained offline tarball" >&2; exit 1; }
[ -f "${BUILDROOT}/.cargo/config.toml" ]  || { echo "rustc: FATAL .cargo/config.toml absent — the in-tree vendor redirect IS the offline mechanism" >&2; exit 1; }
grep -q 'vendored-sources' "${BUILDROOT}/.cargo/config.toml" || {
  echo "rustc: FATAL .cargo/config.toml does not redirect crates-io to vendored-sources" >&2; exit 1; }
SVER="$(cat "${BUILDROOT}/src/version" 2>/dev/null || echo MISSING)"
[ "${SVER}" = "${VERSION}" ] || { echo "rustc: FATAL src/version = '${SVER}', expected ${VERSION} — wrong source extracted" >&2; exit 1; }
# x.py accepts a stage0 in the same minor or one minor behind, ignoring the patch level, and
# upstream pins the .0 of the prior minor; assert the minor line, not the exact patch.
STAGE0_MINOR="${STAGE0_VERSION%.*}"   # e.g. 1.91.1 -> 1.91
grep -qE "compiler_version=${STAGE0_MINOR}\.[0-9]+" "${BUILDROOT}/src/stage0" || {
  echo "rustc: FATAL src/stage0 compiler_version not in the ${STAGE0_MINOR}.x line (our stage0 is ${STAGE0_VERSION}) — wrong bootstrap pairing" >&2
  grep -i 'compiler_' "${BUILDROOT}/src/stage0" >&2 || true
  exit 1; }
S0PIN="$(grep -oE 'compiler_version=[0-9.]+' "${BUILDROOT}/src/stage0" | head -1)"
echo "rustc SOURCE: OK — src/version=${SVER}, src/stage0 ${S0PIN} matches our stage0 ${STAGE0_VERSION} minor line (x.py minor-rule)" >&2

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
echo "rustc: FATAL — the build invoked '${t}', which must never happen offline" >&2
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
    echo "rustc: FATAL — git NETWORK verb attempted: \$*" >&2; exit 1 ;;
  *)
    # unknown verb: default deny, so a new network path cannot slip through
    echo "git \$*" >> "${BUILDROOT}/NETWORK-TRIPWIRE"
    echo "rustc: FATAL — git invoked with an un-allowlisted verb (default-deny): \$*" >&2; exit 1 ;;
esac
EOF
chmod 0755 "${STUBS}/git"

PATH="${STUBS}:${PATH}"; export PATH
[ "$(command -v curl)" = "${STUBS}/curl" ] || {
  echo "rustc: FATAL the curl stub is NOT shadowing the real curl (packages/cmake pulls one in)." >&2
  echo "      command -v curl = $(command -v curl)" >&2; exit 1; }
[ "$(command -v git)" = "${STUBS}/git" ] || { echo "rustc: FATAL the git stub is NOT first on PATH" >&2; exit 1; }

export CARGO_NET_OFFLINE=true
export GIT_CEILING_DIRECTORIES="${BUILDROOT}"
export GIT_CONFIG_NOSYSTEM=1
export GIT_TERMINAL_PROMPT=0

# cargo merges every .cargo/config[.toml] from the build root up to /; one planted above the
# build root could override [source.crates-io] and re-enable the network.  Fail shut.
d="${BUILDROOT}"
while [ "${d}" != "/" ] && [ -n "${d}" ]; do
  # the source's own .cargo at ${BUILDROOT} is the vendor redirect; anything above it is the hazard
  if [ "${d}" != "${BUILDROOT}" ] && [ -e "${d}/.cargo" ]; then
    echo "rustc: FATAL ambient .cargo/ found at ${d} — cargo would merge it and could re-enable the network" >&2; exit 1
  fi
  d="$(dirname "${d}")"
done
[ -e "/.cargo" ] && { echo "rustc: FATAL ambient /.cargo/ present" >&2; exit 1; }
unset d

# The stage0 rustc's default linker is the literal `cc`.  x.py passes -C linker=clang from
# bootstrap.toml, but alias cc/c++ to clang for any tool that shells `cc` directly.
ln -sf "$(command -v clang)"   "${STUBS}/cc"
ln -sf "$(command -v clang++)" "${STUBS}/c++"
command -v cc >/dev/null 2>&1 || { echo "rustc: FATAL cc alias not on PATH" >&2; exit 1; }

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
      echo "rustc SUBMOD: NOTE ${d#"${BUILDROOT}"/} ships no sources; NOT marking (expecting the pkg-config path)" >&2
      continue
    fi
    if [ ! -e "${d}/.git" ]; then
      : > "${d}/.git"
      marked=$((marked + 1))
      echo "rustc SUBMOD: marked ${d#"${BUILDROOT}"/}/.git" >&2
    fi
  done
done
echo "rustc SUBMOD: ${marked} vendored submodule marker(s) placed" >&2
# Diagnostic (non-fatal): whether pkg-config sees the system libs, so the log shows which path
# curl-sys/libssh2-sys will take if a marker was skipped.
for lib in libcurl libssh2; do
  if pkg-config --exists "${lib}" 2>/dev/null; then
    echo "rustc SUBMOD: pkg-config sees ${lib} $(pkg-config --modversion "${lib}" 2>/dev/null)" >&2
  else
    echo "rustc SUBMOD: NOTE pkg-config does NOT see ${lib} — the crate MUST use its vendored submodule (marker required above)" >&2
  fi
done

# --- P1 bootstrap.toml ---
# The tarball ships only bootstrap.example.toml, so the config is generated in full.  Same shape
# as packages/rust/bootstrap.toml, with [build] rustc/cargo pinned at the stage0 and [install]
# prefix set to the private versioned path.
cat > "${BUILDROOT}/bootstrap.toml" <<EOF
# change-id="ignore" silences the version-specific change-id warning without baking a wrong id.
change-id = "ignore"

[build]
rustc = "${STAGE0_RUSTC}"
cargo = "${STAGE0_CARGO}"
# vendor=false: with build.vendor on, bootstrap passes cargo --frozen, which newer stage0 cargos
# abort on ("cannot update the lock file").  The in-tree .cargo config keeps the build offline.
vendor = false
build-stage = 2
test-stage = 2
doc-stage = 2
extended = true
# no "src": the Src component's install path runs a cargo-vendor step that needs the network,
# and shipping rust-src would pollute the next rung's stage0.
tools = ["cargo", "clippy", "rustfmt", "rust-analyzer"]
compiletest-use-stage0-libtest = false
docs = false

[dist]
# x.py install would otherwise run `cargo vendor` for generate-copyright and assemble a source
# tarball, both of which need the network.
vendor = false
src-tarball = false

[llvm]
link-shared = true

[rust]
channel = "stable"
# required with build.vendor=false: the debuginfo remap enumerates \$CARGO_HOME/registry/src,
# which does not exist offline.
remap-debuginfo = false
download-rustc = false
lld = false
llvm-bitcode-linker = false

[target.${TRIPLE}]
cc = "clang"
cxx = "clang++"
linker = "clang"
llvm-config = "/usr/bin/llvm-config"

[install]
prefix = "${PREFIX}"
EOF
grep -q "rustc = \"${STAGE0_RUSTC}\"" "${BUILDROOT}/bootstrap.toml" || { echo "rustc: FATAL bootstrap.toml stage0 rustc pin missing" >&2; exit 1; }
echo "rustc CONFIG: bootstrap.toml generated (stage0 pinned, prefix ${PREFIX})" >&2

# --- P2 x.py build ---
# Offline is structural: the in-tree .cargo vendor redirect, the stage0 pin (no stage0 download),
# external llvm-config (no LLVM download) and P0c's markers.  CARGO_NET_OFFLINE is belt-and-braces.
# cwd is BUILDROOT so ./x.py finds bootstrap.toml.  Do not export RUSTC_BOOTSTRAP: x.py sets it
# per invocation and a global value interferes.
# Neutralize bootstrap's Vendor step: the install-time generate-copyright Vendor step is a default
# step no [dist]/[build] flag suppresses, and offline it fails ("no matching package named
# serde_core").  Gate it behind an env flag with an early return before the Command is built
# (bootstrap panics on a constructed-but-unexecuted Command).  This patches build tooling only.
VENDOR_RS=src/bootstrap/src/core/build_steps/vendor.rs
grep -q 'BOOTSTRAP_SKIP_VENDOR' "$VENDOR_RS" || {
  sed -i 's|let _guard = builder.group(&format!("Vendoring sources|if std::env::var_os("BOOTSTRAP_SKIP_VENDOR").is_some() { return VendorOutput { config: String::new() }; }\n        let _guard = builder.group(\&format!("Vendoring sources|' "$VENDOR_RS"
  grep -q 'BOOTSTRAP_SKIP_VENDOR' "$VENDOR_RS" || { echo "rustc: FATAL vendor.rs early-return patch did not apply" >&2; exit 1; }
}
export BOOTSTRAP_SKIP_VENDOR=1

./x.py build -j "${JOBS}"

# --- offline tripwire, checkpoint 1 (after the build, before install) ---
if [ -e "${BUILDROOT}/NETWORK-TRIPWIRE" ]; then
  echo "rustc: FATAL the build attempted a network fetch:" >&2; cat "${BUILDROOT}/NETWORK-TRIPWIRE" >&2; exit 1
fi
[ -e "${BUILDROOT}/GIT-LOCAL.log" ] && {
  echo "rustc OFFLINE: NOTE — permitted local git probes occurred (harmless, no network verb):" >&2
  sort -u "${BUILDROOT}/GIT-LOCAL.log" >&2; }
echo "rustc OFFLINE: PASS (no curl/wget, no network-capable git verb, during the build)" >&2

# --- P3 install ---
# DESTDIR is prepended to every written path but baked into no file; `prefix` is the logical path
# baked into the toolchain, so files land at ${DST} while baked references say ${PREFIX}.
# Explicit components: a bare `x.py install` reaches the Src component's dist steps regardless of
# the [build] tools list.
DESTDIR="${OUTPUT_DIR}" ./x.py install library/std compiler/rustc cargo clippy rustfmt rust-analyzer

[ -x "${DST}/bin/rustc" ] || { echo "rustc: FATAL install produced no ${DST}/bin/rustc" >&2; exit 1; }
[ -x "${DST}/bin/cargo" ] || { echo "rustc: FATAL install produced no ${DST}/bin/cargo (extended=true should install it)" >&2; exit 1; }
[ -d "${DST}/lib/rustlib/${TRIPLE}/lib" ] || { echo "rustc: FATAL installed std sysroot missing at ${DST}/lib/rustlib/${TRIPLE}/lib" >&2; exit 1; }
ls "${DST}"/lib/librustc_driver*.so >/dev/null 2>&1 || { echo "rustc: FATAL librustc_driver*.so missing from ${DST}/lib" >&2; exit 1; }

# rust-gdbgui is a shell script with a re-rooted path; packages/rust drops it too.
rm -f "${DST}/bin/rust-gdbgui"
# The next rung needs only bin/{rustc,cargo} + lib/; pruning keeps the single output glob's
# coverage complete (no share/man/doc/libexec left uncaptured).
rm -rf "${DST}/share" "${DST}/libexec" "${DST}/etc"

echo "rustc INSTALL: layout below (bin/ + lib/ only):" >&2
ls -la "${DST}" >&2 || true

cat > "${DST}/BUILDINFO" <<EOF
rustc-version: ${VERSION}
built-by-stage0: rustc ${STAGE0_VERSION} (${S0V}) from ${STAGE0_PREFIX}
host-cc: clang (packages/llvm ${LLVMVER})
host-llvm: external /usr/bin/llvm-config (${LLVMVER}), link-shared
target: ${TRIPLE}
offline: in-tree .cargo vendor redirect; stage0 pin skips src/stage0 download; external llvm-config; vendored -sys submodule markers
seal-status: see rustc-${VERSION}.answers
EOF

# --- P4 path sweep (diagnostic, non-fatal) ---
# (a) ${BUILDROOT}: rustc bakes source paths into DWARF, so a hit is usually benign debuginfo.
# (b) ${OUTPUT_DIR}: the DESTDIR staging prefix in an installed text file is a relocation defect
#     that would break the next rung's stage0.  Reported loudly, not fatal.  `grep -I` skips binaries.
hits_b="$(find "${DST}" -type f -exec grep -I -l -F "${BUILDROOT}" {} + 2>/dev/null || true)"
if [ -n "${hits_b}" ]; then
  echo "rustc SWEEP: NOTE — build-root (source) paths present in installed TEXT files (review, not fatal):" >&2
  echo "${hits_b}" >&2
else
  echo "rustc SWEEP: clean of build-root paths" >&2
fi
hits_o="$(find "${DST}" -type f -exec grep -I -l -F "${OUTPUT_DIR}" {} + 2>/dev/null || true)"
if [ -n "${hits_o}" ]; then
  echo "rustc SWEEP: ⚠ WARNING — DESTDIR STAGING paths (${OUTPUT_DIR}) baked into installed TEXT files." >&2
  echo "            This is a RELOCATION DEFECT — the next rung's stage0 would carry a dead path." >&2
  echo "            Non-fatal; must be fixed before sealing:" >&2
  echo "${hits_o}" >&2
else
  echo "rustc SWEEP: clean of staging paths (relocatable)" >&2
fi

# --- P5 gates: run the installed binaries from ${OUTPUT_DIR}, after install ---
# GATE-3 runs ten std constructs whose exit code is their computed sum (42), never a literal.
# GATE-4/5 build and load a proc-macro (directly, then via cargo): the next rung's x.py is
# cargo-driven and derive-heavy, so a rustc that cannot dlopen a proc-macro must fail here.
# The gate sources are heredoc'd inline so the recipe is self-contained; the gate*.rs files in
# this directory are readable copies of the same bodies.  Every gated command is rc-captured
# because `set -e` would abort before the named assert.
RUSTC="${DST}/bin/rustc"
CARGO="${DST}/bin/cargo"
RLIB="${DST}/lib/rustlib/${TRIPLE}/lib"
G="${BUILDROOT}/gate"; mkdir -p "${G}"

# --- GATE-1: identity (not a functional gate) ---
# channel="stable" gives a bare `rustc <version> (...)` with no suffix.
set +e; RV="$("${RUSTC}" --version 2>&1)"; rc=$?; set -e
[ ${rc} -eq 0 ] || { echo "rustc GATE-1: FAIL (installed rustc did not execute, rc=${rc}) — ${RV}" >&2; exit 1; }
echo "${RV}" | grep -qF "${VERSION}" || {
  echo "rustc GATE-1: FAIL — rustc --version = '${RV}', expected to contain '${VERSION}'" >&2; exit 1; }
echo "rustc GATE-1: PASS (identity ${RV})" >&2

# --- GATE-2: rlib production + cross-crate read-back ---
cat > "${G}/gatelib.rs" <<'RSEOF'
pub trait Shape { fn area(&self) -> i64; }
pub struct Sq(pub i64);
impl Shape for Sq { fn area(&self) -> i64 { self.0 * self.0 } }
/// wrapping arithmetic so the result is a computed value, not a constant.
pub fn checksum(v: &[i64]) -> i64 {
    let mut acc: i64 = 7;
    for x in v { acc = acc.wrapping_mul(31).wrapping_add(*x); }
    acc
}
RSEOF
set +e
( cd "${G}" && "${RUSTC}" --crate-type=rlib --crate-name=gatelib -L "${RLIB}" gatelib.rs -o libgatelib.rlib ) >"${G}/g2.log" 2>&1
rc=$?; set -e
[ ${rc} -eq 0 ] && [ -s "${G}/libgatelib.rlib" ] || {
  echo "rustc GATE-2: FAIL (rc=${rc}) — could not emit an rlib." >&2; tail -40 "${G}/g2.log" >&2 || true; exit 1; }
echo "rustc GATE-2: PASS (emitted a non-empty rlib)" >&2

# --- GATE-3: ten std constructs, compiled and executed, computed sum == 42 ---
# Each construct exits with its own code (111-120) so a failure names the miscompiled path.
# c4 dispatches across the crate boundary into GATE-2's rlib, proving it was read back.
cat > "${G}/gatestd.rs" <<'RSEOF'
extern crate gatelib;
use std::collections::{BTreeMap, HashMap};
use std::sync::{Arc, Mutex};
use gatelib::{Shape, Sq};
fn c6_inner(s: &str) -> Result<i64, std::num::ParseIntError> {
    let n: i64 = s.parse()?;
    let doubled = Some(n).map(|v| v + 3).unwrap_or(0);
    Ok(doubled)
}
fn main() {
    // 111: Vec + iterator adaptors + heap
    let squares: Vec<i64> = (1..=10i64).filter(|n| n % 2 == 1).map(|n| n * n).collect();
    let s: i64 = squares.iter().sum();
    if s != 165 { std::process::exit(111); }
    let c1 = s / 33; // 5
    // 112: core::fmt + String + str::parse round-trip
    let hex = format!("{:04x}", 29);
    let back: i64 = format!("{}", s).parse().unwrap_or(-1);
    if hex != "001d" || back != 165 { std::process::exit(112); }
    let c2 = hex.len() as i64; // 4
    // 113: BTreeMap ordering + HashMap hashing (RandomState -> OS entropy)
    let mut bt: BTreeMap<i64, &str> = BTreeMap::new();
    bt.insert(30, "c"); bt.insert(10, "a"); bt.insert(20, "b");
    let ordered: Vec<i64> = bt.keys().cloned().collect();
    let mut hm: HashMap<&str, i64> = HashMap::new();
    hm.insert("a", 1); hm.insert("b", 2); hm.insert("c", 3);
    if ordered != vec![10, 20, 30] || hm.get("b") != Some(&2) || hm.len() != 3 { std::process::exit(113); }
    let c3 = bt.len() as i64; // 3
    // 114: cross-crate Box<dyn Trait> vtable dispatch into the rlib
    let shapes: Vec<Box<dyn Shape>> = vec![Box::new(Sq(5)), Box::new(Sq(2))];
    let area: i64 = shapes.iter().map(|sh| sh.area()).sum();
    let ck = gatelib::checksum(&[1, 2, 3]);
    if area != 29 || ck != 209_563 { std::process::exit(114); }
    let c4 = shapes[0].area() / 5; // 5
    // 115: generics + FnMut capture
    fn apply<F: FnMut(i64)>(times: i64, mut f: F) { for i in 0..times { f(i); } }
    let mut counter: i64 = 0;
    apply(4, |_| counter += 2);
    if counter != 8 { std::process::exit(115); }
    let c5 = counter / 2; // 4
    // 116: Result + `?` + Option combinators
    let r = c6_inner("14");
    let bad = c6_inner("not-a-number");
    if r != Ok(17) || bad.is_ok() { std::process::exit(116); }
    let c6 = r.unwrap() % 14; // 3
    // 117: catch_unwind — unwinding through panic_unwind
    let prev = std::panic::take_hook();
    std::panic::set_hook(Box::new(|_| {}));
    let caught = std::panic::catch_unwind(|| { panic!("boomba"); });
    std::panic::set_hook(prev);
    let plen = match caught {
        Ok(_) => std::process::exit(117),
        Err(e) => match e.downcast_ref::<&str>() { Some(msg) => msg.len() as i64, None => std::process::exit(117) },
    };
    if plen != 6 { std::process::exit(117); }
    let c7 = plen; // 6
    // 118: checked/wrapping overflow semantics
    if i64::max_value().checked_add(1).is_some() { std::process::exit(118); }
    let w: u8 = 250u8.wrapping_add(10);
    if w != 4 { std::process::exit(118); }
    let c8 = w as i64; // 4
    // 119: f64 format + parse round-trip
    let f: f64 = "2.5".parse().unwrap_or(0.0);
    let prod = f * 1.6;
    if format!("{:.1}", prod) != "4.0" { std::process::exit(119); }
    let c9 = prod as i64; // 4
    // 120: threads + join + Arc<Mutex<_>> (pthreads, TLS, atomics)
    let shared = Arc::new(Mutex::new(0i64));
    let mut handles = Vec::new();
    for _ in 0..4 {
        let h = Arc::clone(&shared);
        handles.push(std::thread::spawn(move || { let mut g = h.lock().unwrap(); *g += 1; }));
    }
    for h in handles { let joined = h.join(); if joined.is_err() { std::process::exit(120); } }
    let threaded = *shared.lock().unwrap();
    if threaded != 4 { std::process::exit(120); }
    let c10 = threaded; // 4
    // 5+4+3+5+4+3+6+4+4+4 == 42, computed, never a literal.
    let total = c1 + c2 + c3 + c4 + c5 + c6 + c7 + c8 + c9 + c10;
    std::process::exit(total as i32);
}
RSEOF
set +e
( cd "${G}" && "${RUSTC}" -L "${RLIB}" --extern gatelib="${G}/libgatelib.rlib" gatestd.rs -o gatestd ) >"${G}/g3-compile.log" 2>&1
rc=$?; set -e
[ ${rc} -eq 0 ] || { echo "rustc GATE-3: FAIL (rc=${rc}) — could not compile the gate program:" >&2; tail -60 "${G}/g3-compile.log" >&2 || true; exit 1; }
set +e; "${G}/gatestd"; rc=$?; set -e
case ${rc} in
  42) : ;;
  111) echo "rustc GATE-3: FAIL — iterator/closure/heap" >&2; exit 1 ;;
  112) echo "rustc GATE-3: FAIL — core::fmt / parse round-trip" >&2; exit 1 ;;
  113) echo "rustc GATE-3: FAIL — BTreeMap/HashMap" >&2; exit 1 ;;
  114) echo "rustc GATE-3: FAIL — CROSS-CRATE vtable dispatch into the rlib" >&2; exit 1 ;;
  115) echo "rustc GATE-3: FAIL — generics + FnMut capture" >&2; exit 1 ;;
  116) echo "rustc GATE-3: FAIL — Result + '?' + Option" >&2; exit 1 ;;
  117) echo "rustc GATE-3: FAIL — catch_unwind / UNWINDING" >&2; exit 1 ;;
  118) echo "rustc GATE-3: FAIL — checked/wrapping overflow" >&2; exit 1 ;;
  119) echo "rustc GATE-3: FAIL — f64 round-trip" >&2; exit 1 ;;
  120) echo "rustc GATE-3: FAIL — threads + Arc<Mutex>" >&2; exit 1 ;;
  139) echo "rustc GATE-3: FAIL — SIGSEGV (rc=139). Suspect an rlib/dylib std ABI mismatch." >&2; exit 1 ;;
  126|127) echo "rustc GATE-3: FAIL — rc=${rc}: bad interpreter or missing DSO (loader/rpath)" >&2; exit 1 ;;
  *)   echo "rustc GATE-3: FAIL — gate binary exited ${rc}, expected the computed 42" >&2; exit 1 ;;
esac
echo "rustc GATE-3: PASS (ten std constructs compiled, linked and RAN; computed 42)" >&2

# --- GATE-4: proc-macro built as a dylib, loaded, expanded, run -> computed 42 ---
cat > "${G}/gate_pm.rs" <<'RSEOF'
extern crate proc_macro;
use proc_macro::TokenStream;
#[proc_macro_derive(GateVal)]
pub fn gate_val(_input: TokenStream) -> TokenStream {
    // 13 is produced inside the proc-macro dylib and checked by the consumer.
    "impl Target { fn val(&self) -> i64 { 13 } }".parse().unwrap()
}
RSEOF
cat > "${G}/gate_pm_use.rs" <<'RSEOF'
#[macro_use]
extern crate gate_pm;
#[derive(GateVal)]
struct Target;
fn main() {
    let t = Target;
    let v = t.val();          // exists only because the proc macro ran
    if v != 13 { std::process::exit(121); }
    std::process::exit((v * 3 + 3) as i32);  // 42, computed
}
RSEOF
set +e
( cd "${G}" && "${RUSTC}" --crate-type=proc-macro --crate-name=gate_pm -L "${RLIB}" gate_pm.rs -o libgate_pm.so ) >"${G}/g4-pm.log" 2>&1
rc=$?; set -e
if [ ${rc} -ne 0 ]; then
  echo "rustc GATE-4: FAIL (rc=${rc}) — could not build a proc-macro crate; this rustc cannot serve as the next rung's stage0 (x.py needs proc-macros)." >&2
  ls -la "${RLIB}" | grep -i proc_macro >&2 || echo "             (no proc_macro artifact in ${RLIB})" >&2
  tail -40 "${G}/g4-pm.log" >&2 || true; exit 1
fi
set +e
( cd "${G}" && "${RUSTC}" -L "${RLIB}" --extern gate_pm="${G}/libgate_pm.so" gate_pm_use.rs -o gate_pm_use ) >"${G}/g4-use.log" 2>&1
rc=$?; set -e
[ ${rc} -eq 0 ] || { echo "rustc GATE-4: FAIL (rc=${rc}) — rustc could not LOAD and EXPAND the proc macro:" >&2; tail -40 "${G}/g4-use.log" >&2 || true; exit 1; }
set +e; "${G}/gate_pm_use"; rc=$?; set -e
[ ${rc} -eq 42 ] || { echo "rustc GATE-4: FAIL — proc-macro consumer exited ${rc}, expected 42" >&2; [ ${rc} -eq 121 ] && echo "             (121 = macro expanded but produced the wrong value)" >&2; exit 1; }
echo "rustc GATE-4: PASS (proc-macro crate built as a dylib, dlopen'd, expanded, and RAN)" >&2

# --- GATE-5: cargo drives a build of a proc-macro crate + a #[derive] consumer -> 42 ---
# Zero registry deps, so no vendor dir or network is involved.
CW="${G}/cargows"
mkdir -p "${CW}/pmderive/src" "${CW}/app/src"
cat > "${CW}/pmderive/Cargo.toml" <<'EOF'
[workspace]
[package]
name = "pmderive"
version = "0.0.0"
edition = "2015"
[lib]
proc-macro = true
EOF
cat > "${CW}/pmderive/src/lib.rs" <<'RSEOF'
extern crate proc_macro;
use proc_macro::TokenStream;
#[proc_macro_derive(GateVal)]
pub fn gate_val(_input: TokenStream) -> TokenStream {
    "impl Target { fn val(&self) -> i64 { 13 } }".parse().unwrap()
}
RSEOF
cat > "${CW}/app/Cargo.toml" <<'EOF'
# an explicit [workspace] makes this app its own root, so cargo does not adopt a stray Cargo.toml above the build dir
[workspace]
[package]
name = "gateapp"
version = "0.0.0"
edition = "2015"
[dependencies]
pmderive = { path = "../pmderive" }
EOF
cat > "${CW}/app/src/main.rs" <<'RSEOF'
#[macro_use]
extern crate pmderive;
#[derive(GateVal)]
struct Target;
fn main() {
    let t = Target;
    let v = t.val();
    if v != 13 { std::process::exit(121); }
    std::process::exit((v * 3 + 3) as i32); // 42, computed
}
RSEOF
set +e
( cd "${CW}/app" && CARGO_HOME="${CW}/home" RUSTC="${RUSTC}" \
    "${CARGO}" build --offline --release --target-dir "${CW}/target" ) >"${G}/g5.log" 2>&1
rc=$?; set -e
[ ${rc} -eq 0 ] || { echo "rustc GATE-5: FAIL (rc=${rc}) — cargo could not drive a proc-macro + derive build:" >&2; tail -50 "${G}/g5.log" >&2 || true; exit 1; }
set +e; "${CW}/target/release/gateapp"; rc=$?; set -e
[ ${rc} -eq 42 ] || { echo "rustc GATE-5: FAIL — cargo-built binary exited ${rc}, expected 42" >&2; exit 1; }
echo "rustc GATE-5: PASS (cargo built a proc-macro crate + a #[derive] consumer, and the binary RAN; computed 42)" >&2

# --- GATE-6: glibc interpreter + offline re-assert ---
INTERP="$(readelf -l "${DST}/bin/rustc" 2>/dev/null | grep -o '/[^]]*ld-linux[^]]*' | head -1 || true)"
case "${INTERP}" in
  */ld-linux-*) echo "rustc GATE-6: rustc interp = ${INTERP}" >&2 ;;
  *) echo "rustc GATE-6: FAIL — rustc has no recognizable glibc interpreter (got '${INTERP}')" >&2; exit 1 ;;
esac
if [ -e "${BUILDROOT}/NETWORK-TRIPWIRE" ]; then
  echo "rustc: FATAL a network fetch was attempted during the gate phase:" >&2; cat "${BUILDROOT}/NETWORK-TRIPWIRE" >&2; exit 1
fi
echo "rustc GATE-6: PASS (glibc interp; network tripwire clean after all gates)" >&2

# --- P6 seal ---
# If rustc-${VERSION}.answers carries sha256 pins, the installed bin/rustc and bin/cargo must
# match them; with no pins the check is skipped.  Sealing is a data edit to the .answers file.
ANS="${BUILDROOT}/rustc-${VERSION}.answers"
if [ -f "${ANS}" ] && grep -Eq '^[0-9a-f]{64}  ' "${ANS}"; then
  if ( cd "${OUTPUT_DIR}" && sha256sum -c "${ANS}" ); then
    echo "rustc SEAL: PASS (byte-identical to the pinned answers)" >&2
  else
    echo "rustc SEAL: FAIL (output drifted from rustc-${VERSION}.answers)" >&2; exit 1
  fi
else
  echo "rustc SEAL: no pins present; seal not checked" >&2
fi

echo "rustc: ALL GATES PASSED — rustc ${VERSION} installed at ${PREFIX}, ready as the next rung's stage0." >&2
