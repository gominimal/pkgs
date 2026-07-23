#!/bin/sh
# ============================================================================================
# build.sh — rustc 1.91.1, built by the CS-attested rustc 1.90.0 (RUNG 1) via STANDARD x.py.
# RUNG 2 of 5 toward deleting packages/rust's unattested seed tarballs (issue #17). See build.ncl.
#
# This is a SYNTHESIS: packages/rust's x.py core (generate bootstrap.toml -> ./x.py build ->
# DESTDIR install) with (1) stage0 = the previous rung's installed prefix, (2) a PRIVATE
# versioned install prefix, (3) RUNG 1's strict-offline P0b harness, (4) RUNG 1's FUNCTIONAL
# gates.  packages/rust itself is offline-UNSAFE for a chain rung (it declares `needs internet`
# and carries no curl/wget/git stubs), so it must NOT be cloned verbatim.
#
# Phases:
#   P0   preconditions   — clang/llvm-config on PATH; stage0 rustc+cargo assert BY NAME and by
#                          --version/--print sysroot; the extracted source is the RIGHT one
#                          (src/version==1.91.1 AND src/stage0 pins compiler_version==1.90.0)
#   P0b  offline harness  — curl/wget fail-shut; git allows only LOCAL probes; ambient-.cargo guard
#   P0c  submodule markers — empty .git in each vendored -sys submodule so its build.rs does NOT
#                            take the `git submodule update --init` branch our git stub fail-shuts
#   P1   bootstrap.toml   — generated in full; [build] rustc/cargo pinned at the stage0 prefix
#   P2   ./x.py build     — real rustc, offline via the in-tree .cargo vendor redirect
#   P3   install          — DESTDIR + versioned prefix; prune to bin/+lib/; BUILDINFO
#   P4   path sweep       — build-root AND staging-root leak DIAGNOSTIC (relocatability tripwire)
#   P5   gates            — FUNCTIONAL, run from ${OUTPUT_DIR}, AFTER install; computed 42, never
#                           a literal, and the two highest-value ones exercise proc-macros + cargo
#   P6   seal             — self-arming, ships UNPINNED (not expected 2-run identical yet)
#
# Every assertion is fail-shut with a NAMED message.  This rung has never been built in CS and
# runs for hours; the first failure must be diagnosable from one log read.
#
# ── HOW TO CLONE THIS FILE FOR RUNGS 3/4/5 ───────────────────────────────────────────────────
# Change ONLY the two lines VERSION= and STAGE0_VERSION= below.  Everything else — including the
# stage0 PREFIX shape — derives from them (see the STAGE0_PREFIX case: 1.90.0 is the irregular
# mrustc prefix, every later rung is /usr/lib/rustc-<v>).  The build.ncl deltas are in README.md.
# ============================================================================================
set -ex

VERSION=1.91.1
STAGE0_VERSION=1.90.0
TRIPLE=x86_64-unknown-linux-gnu

BUILDROOT="$(pwd)"
PREFIX="/usr/lib/rustc-${VERSION}"        # PRIVATE versioned prefix (NOT /usr/bin)
DST="${OUTPUT_DIR}${PREFIX}"              # staged install location = ${DESTDIR}${prefix}

# stage0 = the PREVIOUS rung's installed prefix, consumed as a build_dep (NOT extracted tarballs).
# RUNG 1 (1.90.0) is an mrustc build and installed at the IRREGULAR /usr/lib/mrustc-rust-1.90.0;
# every LATER rung (this file, cloned) installs at the REGULAR /usr/lib/rustc-<v>.  Derive the
# right shape from STAGE0_VERSION so rungs 3+ are a byte-identical clone of this file.
case "${STAGE0_VERSION}" in
  1.90.0) STAGE0_PREFIX="/usr/lib/mrustc-rust-${STAGE0_VERSION}" ;;  # RUNG 1 only
  *)      STAGE0_PREFIX="/usr/lib/rustc-${STAGE0_VERSION}" ;;         # rungs 3+
esac
STAGE0_RUSTC="${STAGE0_PREFIX}/bin/rustc"  # RUNG 1: a POSIX-sh WRAPPER (sets LD_LIBRARY_PATH),
                                           # NOT rustc_binary.  Rungs 3+: a real ELF.  Both work
                                           # in-place because --print sysroot resolves either way.
STAGE0_CARGO="${STAGE0_PREFIX}/bin/cargo"

JOBS="$(nproc 2>/dev/null || echo 4)"

case "$(uname -m)" in
  x86_64)  MARCH="-march=x86-64-v3" ;;
  aarch64) MARCH="-march=armv8-a" ;;
  *)       MARCH="" ;;
esac
# Verbatim from packages/rust/build.sh:4-13 — proven CFLAGS for this era.  -ffile-prefix-map keeps
# the build root out of C debug info (helps P4's sweep).
export CFLAGS="${MARCH} -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=${BUILDROOT}=/builddir"
export CXXFLAGS="${CFLAGS}"
export LDFLAGS="-Wl,--build-id=none"
export LIBSQLITE3_SYS_USE_PKG_CONFIG=1
export LIBSSH2_SYS_USE_PKG_CONFIG=1

# ============================================================================================
# P0 — PRECONDITIONS.  Assert the STAGE0, not just "a rustc".
# ============================================================================================
for t in clang clang++ llvm-config ar ranlib python3 pkg-config cmake \
         find sed grep tar xz sha256sum readelf; do
  command -v "${t}" >/dev/null 2>&1 || { echo "r191 infra: '${t}' not on PATH" >&2; exit 1; }
done

LLVMVER="$(llvm-config --version 2>/dev/null || echo unknown)"
case "${LLVMVER}" in
  21.*) : ;;
  *) echo "r191 infra: llvm-config --version = '${LLVMVER}', expected 21.x (rustc 1.91.1 targets LLVM 21)." >&2
     echo "            A too-new/too-old external LLVM hard-errors at x.py configure.  Refusing." >&2
     exit 1 ;;
esac

# --- ★ THE STAGE0: the CS-attested PREVIOUS-RUNG binaries -----------------------------------
[ -x "${STAGE0_RUSTC}" ] || { echo "r191: FATAL stage0 rustc missing at ${STAGE0_RUSTC} — the previous rung's package is THE anchor of this rung" >&2; exit 1; }
[ -x "${STAGE0_CARGO}" ] || { echo "r191: FATAL stage0 cargo missing at ${STAGE0_CARGO}" >&2; exit 1; }

# The RUNG 1 stage0 rustc reports `1.90.0-stable-mrustc` (built with CFG_VERSION=<v>-stable-mrustc).
# Its release component is 1.90.0, which is what x.py's stage0 check parses.  We assert 1.90.0 is
# PRESENT (substring); x.py's OWN stage0-version check runs SECONDS into the build (fast-fail, NOT
# a 20h loss) — see the FAST-FAIL risk in build.ncl / README about the `-stable-mrustc` suffix.
# (Rungs 3+ consume a real-ELF rustc reporting a clean `1.9x.y`; the substring check works for both.)
S0V="$("${STAGE0_RUSTC}" --version 2>&1 || true)"
echo "${S0V}" | grep -qF "${STAGE0_VERSION}" || {
  echo "r191: FATAL stage0 rustc --version = '${S0V}', expected to contain ${STAGE0_VERSION}" >&2; exit 1; }
# The stage0 rustc must resolve its own sysroot to the stage0 prefix (proves it works in-place AND
# that its bundled std is where x.py will look for it).  Works for a wrapper OR a real ELF.
S0SR="$("${STAGE0_RUSTC}" --print sysroot 2>&1 || true)"
[ "${S0SR}" = "${STAGE0_PREFIX}" ] || {
  echo "r191: FATAL stage0 rustc --print sysroot = '${S0SR}', expected ${STAGE0_PREFIX}" >&2; exit 1; }
[ -d "${STAGE0_PREFIX}/lib/rustlib/${TRIPLE}/lib" ] || {
  echo "r191: FATAL stage0 std sysroot missing at ${STAGE0_PREFIX}/lib/rustlib/${TRIPLE}/lib" >&2; exit 1; }
"${STAGE0_CARGO}" --version >/dev/null 2>&1 || { echo "r191: FATAL stage0 cargo did not execute" >&2; exit 1; }
echo "R191-ANCHOR: stage0 OK — ${S0V} (sysroot ${S0SR})" >&2

# --- the extracted source must be the RIGHT one -------------------------------------------
# extract=true means the harness already unpacked + sha-verified the tarball; there is no tarball
# in the build dir to re-sha.  Assert the tree identity instead — a STRONGER check than a sha:
# it proves both the version AND the intended bootstrap pairing.
[ -f "${BUILDROOT}/x.py" ]                || { echo "r191: FATAL x.py absent — source not extracted to build root" >&2; exit 1; }
[ -d "${BUILDROOT}/vendor" ]              || { echo "r191: FATAL vendor/ absent — source is not the self-contained offline tarball" >&2; exit 1; }
[ -f "${BUILDROOT}/.cargo/config.toml" ]  || { echo "r191: FATAL .cargo/config.toml absent — the in-tree vendor redirect IS the offline mechanism" >&2; exit 1; }
grep -q 'vendored-sources' "${BUILDROOT}/.cargo/config.toml" || {
  echo "r191: FATAL .cargo/config.toml does not redirect crates-io to vendored-sources" >&2; exit 1; }
SVER="$(cat "${BUILDROOT}/src/version" 2>/dev/null || echo MISSING)"
[ "${SVER}" = "${VERSION}" ] || { echo "r191: FATAL src/version = '${SVER}', expected ${VERSION} — wrong source extracted" >&2; exit 1; }
grep -q "compiler_version=${STAGE0_VERSION}" "${BUILDROOT}/src/stage0" || {
  echo "r191: FATAL src/stage0 does not pin compiler_version=${STAGE0_VERSION} — the bootstrap pairing is wrong" >&2
  grep -i 'compiler_' "${BUILDROOT}/src/stage0" >&2 || true
  exit 1; }
echo "R191-SOURCE: OK — src/version=${SVER}, src/stage0 pins ${STAGE0_VERSION} (pairing confirmed)" >&2

# ============================================================================================
# P0b — OFFLINE HARNESS (ported verbatim in spirit from mrustc-rustc-1.90.0/build.sh:113-188).
# packages/rust relies on `needs internet` and proves nothing; a chain rung fails SHUT.
#
# curl/wget: fail-shut unconditionally.  A REAL curl is in this rootfs (packages/cmake pulls it in),
# so the proof rests on PATH ORDER — we ASSERT the shadow took.
# git: allow ONLY purely-local probes (rev-parse HEAD/--git-dir/--show-toplevel, --version) that
# x.py's version-stamp and a few vendored build.rs (wasm-bindgen-shared, cranelift-codegen) make
# from a tarball with no .git.  Every caller handles their failure (.output().ok()).  Any
# network-capable verb (clone/fetch/pull/remote/ls-remote/submodule) is a hard tripwire.  DO NOT
# "simplify" this to exit 0 — that deletes the tripwire for the remaining hours.
# ============================================================================================
STUBS="${BUILDROOT}/stubs"; mkdir -p "${STUBS}"
for t in curl wget; do
  cat > "${STUBS}/${t}" <<EOF
#!/bin/sh
echo "\$0 \$*" >> "${BUILDROOT}/NETWORK-TRIPWIRE"
echo "r191: FATAL — the build invoked '${t}', which must never happen offline" >&2
exit 1
EOF
  chmod 0755 "${STUBS}/${t}"
done

cat > "${STUBS}/git" <<EOF
#!/bin/sh
case "\$1 \$2" in
  "rev-parse HEAD"|"rev-parse --git-dir"|"rev-parse --show-toplevel")
    echo "git \$*" >> "${BUILDROOT}/GIT-LOCAL.log"; exit 1 ;;   # real git's out-of-repo behaviour
esac
if [ "\$1" = "--version" ]; then
  echo "git \$*" >> "${BUILDROOT}/GIT-LOCAL.log"; echo "git version 0.0.0-bedrock-stub"; exit 0
fi
echo "git \$*" >> "${BUILDROOT}/NETWORK-TRIPWIRE"
echo "r191: FATAL — the build invoked git with a non-local argv: \$*" >&2
exit 1
EOF
chmod 0755 "${STUBS}/git"

PATH="${STUBS}:${PATH}"; export PATH
[ "$(command -v curl)" = "${STUBS}/curl" ] || {
  echo "r191: FATAL the curl stub is NOT shadowing the real curl (packages/cmake pulls one in)." >&2
  echo "      command -v curl = $(command -v curl)" >&2; exit 1; }
[ "$(command -v git)" = "${STUBS}/git" ] || { echo "r191: FATAL the git stub is NOT first on PATH" >&2; exit 1; }

export CARGO_NET_OFFLINE=true
export GIT_CEILING_DIRECTORIES="${BUILDROOT}"
export GIT_CONFIG_NOSYSTEM=1
export GIT_TERMINAL_PROMPT=0

# AMBIENT-CONFIG HAZARD: cargo walks up to `/` for .cargo/config[.toml]; a stray one planted by
# another package could override [source.crates-io] and silently re-enable the network.  Fail shut.
d="${BUILDROOT}"
while [ "${d}" != "/" ] && [ -n "${d}" ]; do
  # the source's OWN .cargo (the vendor redirect) lives AT ${BUILDROOT}/.cargo and is expected;
  # anything ABOVE the build root is the hazard.
  if [ "${d}" != "${BUILDROOT}" ] && [ -e "${d}/.cargo" ]; then
    echo "r191: FATAL ambient .cargo/ found at ${d} — cargo would merge it and could re-enable the network" >&2; exit 1
  fi
  d="$(dirname "${d}")"
done
[ -e "/.cargo" ] && { echo "r191: FATAL ambient /.cargo/ present" >&2; exit 1; }
unset d

# The stage0 rustc's DEFAULT linker is the literal `cc` (RUNG 1 baked no -C linker=).  x.py passes
# -C linker=clang from bootstrap.toml so `cc` is not needed on the hot path, but alias cc->clang as
# belt-and-braces for any tool that shells `cc` directly (the exact wall RUNG 1 hit).
ln -sf "$(command -v clang)"   "${STUBS}/cc"
ln -sf "$(command -v clang++)" "${STUBS}/c++"
command -v cc >/dev/null 2>&1 || { echo "r191: FATAL cc alias not on PATH" >&2; exit 1; }

# ============================================================================================
# P0c — VENDORED SUBMODULE MARKERS.  ★ THE OFFLINE FIX THE FIRST DRAFT OMITTED. ★
#
# MEASURED on RUNG 1 (mrustc-rustc-1.90.0/build.sh:327-354): a handful of vendored -sys build.rs
# (curl-sys, libssh2-sys) guard on a `.git` marker that the release tarball does NOT ship (0 `.git`
# entries in the whole vendor/ tree) and therefore take an UNCONDITIONAL `git submodule update
# --init` branch.  With curl-sys pulled in transitively by cargo (built LATE under extended=true),
# that branch fires HOURS into ./x.py build, our git stub fail-shuts on `submodule`, and the run
# dies far from a fresh log.  LIBSSH2_SYS_USE_PKG_CONFIG=1 covers libssh2-sys; curl-sys has NO env
# override, so it needs the marker (or a system libcurl via pkg-config — see the diagnostic below).
#
# Creating an EMPTY `.git` marker in each shipped submodule dir makes build.rs believe the submodule
# is already checked out; it then compiles the sources SHIPPED IN THE TARBALL, fully offline.
#
# Checksum-safe: cargo's DirectorySource::verify iterates ONLY the files LISTED in
# .cargo-checksum.json, so an unlisted EXTRA file is never detected (mrustc build.sh:333-337).
# NEVER edit an existing vendored file — THAT trips "the listed checksum of X has changed".
#
# VERSION-AGNOSTIC by design.  RUNG 1 hardcoded exact version-pinned paths
# (curl-sys-0.4.82+curl-8.14.1, curl-sys-0.4.79+curl-8.12.0, libssh2-sys-0.3.1) because it could
# read its tarball; 1.91.1's -sys versions differ and this recipe cannot read the tarball ahead of
# the build.  So GLOB the dirs actually present and mark only those that SHIP SOURCES (marking an
# unpopulated dir would make the crate try to compile an empty checkout — a DIFFERENT hard error).
# The libgit2-sys crate is deliberately NOT in this list: RUNG 1 measured its guard keys on
# libgit2/src (which DOES ship), so it never takes the submodule branch — a marker there is
# cargo-cult.  If a FUTURE rung's build.rs surface changes, RE-DERIVE by reading each guard.
marked=0
for pat in "curl-sys-*/curl" "libssh2-sys-*/libssh2"; do
  # shellcheck disable=SC2231  # intentional glob on ${pat}
  for d in "${BUILDROOT}"/vendor/${pat}; do
    [ -d "${d}" ] || continue
    # does it actually ship sources?  A populated submodule has many entries; an empty one has ~0.
    n="$(find "${d}" -mindepth 1 -maxdepth 1 ! -name .git 2>/dev/null | head -1 | wc -l | tr -d ' ')"
    if [ "${n}" -lt 1 ]; then
      echo "R191-SUBMOD: NOTE ${d#"${BUILDROOT}"/} ships no sources; NOT marking (expecting the pkg-config path)" >&2
      continue
    fi
    if [ ! -e "${d}/.git" ]; then
      : > "${d}/.git"
      marked=$((marked + 1))
      echo "R191-SUBMOD: marked ${d#"${BUILDROOT}"/}/.git" >&2
    fi
  done
done
echo "R191-SUBMOD: ${marked} vendored submodule marker(s) placed" >&2
# DIAGNOSTIC (non-fatal): record whether the system libs are pkg-config-visible, so the log shows
# which path curl-sys/libssh2-sys will take even if a marker was skipped.  A missing marker AND a
# missing .pc for the same lib is the exact combination that fails hours-in on the git stub — this
# line makes that predictable from the first minutes of the log.
for lib in libcurl libssh2; do
  if pkg-config --exists "${lib}" 2>/dev/null; then
    echo "R191-SUBMOD: pkg-config sees ${lib} $(pkg-config --modversion "${lib}" 2>/dev/null)" >&2
  else
    echo "R191-SUBMOD: NOTE pkg-config does NOT see ${lib} — the crate MUST use its vendored submodule (marker required above)" >&2
  fi
done

# ============================================================================================
# P1 — GENERATE bootstrap.toml IN FULL.
#
# The tarball ships only bootstrap.example.toml (a template), so the recipe must PROVIDE the
# config.  Unlike packages/rust (which ships a Local bootstrap.toml and seds the stage0 in), we
# generate it here so the whole rung is self-contained and the stage0 paths are baked directly —
# no sed fragility.  Structure is packages/rust/bootstrap.toml with two deltas: [build] rustc/cargo
# pinned at the stage0, and [install] prefix set to the private versioned path.
# ============================================================================================
cat > "${BUILDROOT}/bootstrap.toml" <<EOF
# change-id="ignore" silences the version-specific change-id warning without baking a wrong id.
# (bootstrap.example.toml for 1.91.1 documents "ignore" as the accepted sentinel.)
change-id = "ignore"

[build]
rustc = "${STAGE0_RUSTC}"
cargo = "${STAGE0_CARGO}"
build-stage = 2
test-stage = 2
doc-stage = 2
extended = true
compiletest-use-stage0-libtest = false
docs = false

[llvm]
link-shared = true

[rust]
channel = "stable"
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
grep -q "rustc = \"${STAGE0_RUSTC}\"" "${BUILDROOT}/bootstrap.toml" || { echo "r191: FATAL bootstrap.toml stage0 rustc pin missing" >&2; exit 1; }
echo "R191-CONFIG: bootstrap.toml generated (stage0 pinned, prefix ${PREFIX})" >&2

# ============================================================================================
# P2 — ./x.py build.  Offline is STRUCTURAL: the in-tree .cargo vendor redirect + the stage0
# pin (no stage0 download) + external llvm-config (no LLVM download) + P0c's submodule markers.
# No --offline flag needed; CARGO_NET_OFFLINE=true is the exported belt-and-braces.
# ============================================================================================
# cwd is BUILDROOT (never changed outside subshells), so ./x.py resolves and finds bootstrap.toml.
# Do NOT export RUSTC_BOOTSTRAP — x.py sets it per-invocation internally; a global value interferes.
./x.py build -j "${JOBS}"

# --- offline tripwire, checkpoint 1 (after the long build, before install) -----------------
if [ -e "${BUILDROOT}/NETWORK-TRIPWIRE" ]; then
  echo "r191: FATAL the build attempted a network fetch:" >&2; cat "${BUILDROOT}/NETWORK-TRIPWIRE" >&2; exit 1
fi
[ -e "${BUILDROOT}/GIT-LOCAL.log" ] && {
  echo "R191-OFFLINE: NOTE — permitted local git probes occurred (harmless, no network verb):" >&2
  sort -u "${BUILDROOT}/GIT-LOCAL.log" >&2; }
echo "R191-OFFLINE: PASS (no curl/wget, no network-capable git verb, during the build)" >&2

# ============================================================================================
# P3 — INSTALL to the private versioned prefix, then PRUNE + BUILDINFO.
#
# DESTDIR is a staging prefix prepended to every written path but baked into NO file; `prefix` is
# the logical path baked into the toolchain.  Files land at ${DST}/... while every baked reference
# says ${PREFIX}/... — exactly where they sit after extraction to the real root.  rustc also
# resolves its sysroot from /proc/self/exe, so it is relocatable regardless.
# ============================================================================================
DESTDIR="${OUTPUT_DIR}" ./x.py install

[ -x "${DST}/bin/rustc" ] || { echo "r191: FATAL install produced no ${DST}/bin/rustc" >&2; exit 1; }
[ -x "${DST}/bin/cargo" ] || { echo "r191: FATAL install produced no ${DST}/bin/cargo (extended=true should install it)" >&2; exit 1; }
[ -d "${DST}/lib/rustlib/${TRIPLE}/lib" ] || { echo "r191: FATAL installed std sysroot missing at ${DST}/lib/rustlib/${TRIPLE}/lib" >&2; exit 1; }
ls "${DST}"/lib/librustc_driver*.so >/dev/null 2>&1 || { echo "r191: FATAL librustc_driver*.so missing from ${DST}/lib" >&2; exit 1; }

# rust-gdbgui is a shell script packages/rust explicitly removes; drop it (path re-rooted).
rm -f "${DST}/bin/rust-gdbgui"
# Prune what the NEXT rung does not consume (it needs only bin/{rustc,cargo}+lib).  Shrinks the
# artifact and keeps the single recursive output glob's coverage complete (no share/man/doc/libexec).
rm -rf "${DST}/share" "${DST}/libexec" "${DST}/etc"

echo "R191-INSTALL: layout below (bin/ + lib/ only):" >&2
ls -la "${DST}" >&2 || true

cat > "${DST}/BUILDINFO" <<EOF
rustc-version: ${VERSION}
built-by-stage0: rustc ${STAGE0_VERSION} (${S0V}) from ${STAGE0_PREFIX} — the previous rung, CS-attested
host-cc: clang (packages/llvm ${LLVMVER})
host-llvm: external /usr/bin/llvm-config (${LLVMVER}), link-shared
target: ${TRIPLE}
offline: in-tree .cargo vendor redirect; stage0 pin skips src/stage0 download; external llvm-config; vendored -sys submodule markers
seal-status: see rustc-${VERSION}.answers (UNPINNED — GREEN, not SEALED)
EOF

# ============================================================================================
# P4 — PATH SWEEP (DIAGNOSTIC, non-fatal).  Two leak classes, both a relocatability hazard:
#   (a) ${BUILDROOT} — the SOURCE dir.  rustc bakes source paths into DWARF, so a hit here is
#       usually a benign debuginfo path (which -ffile-prefix-map already remaps for C; Rust
#       debuginfo may still carry it).  Non-fatal.
#   (b) ${OUTPUT_DIR} — the DESTDIR STAGING prefix.  A correctly-relocatable install bakes only the
#       LOGICAL prefix ${PREFIX}; a hit for the staging path in a TEXT file is a genuine relocation
#       DEFECT that would break the next rung's stage0 consumption.  Still non-fatal (never
#       false-fail an hours-long build over a possible debuginfo edge), but LOUD — fix before
#       consuming this as stage0.  The load-bearing fail-shut lives in the network tripwire + gates.
#
# RUNG 1 made a build-root sweep FATAL because run_rustc bakes an absolute build-scratch path into a
# generated SHELL WRAPPER (bin/rustc).  x.py produces a REAL ELF rustc that resolves its sysroot
# from /proc/self/exe, so that specific class does not arise here.  `grep -I` skips binaries.
# ============================================================================================
hits_b="$(find "${DST}" -type f -exec grep -I -l -F "${BUILDROOT}" {} + 2>/dev/null || true)"
if [ -n "${hits_b}" ]; then
  echo "R191-SWEEP: NOTE — build-root (source) paths present in installed TEXT files (review, not fatal):" >&2
  echo "${hits_b}" >&2
else
  echo "R191-SWEEP: clean of build-root paths" >&2
fi
hits_o="$(find "${DST}" -type f -exec grep -I -l -F "${OUTPUT_DIR}" {} + 2>/dev/null || true)"
if [ -n "${hits_o}" ]; then
  echo "R191-SWEEP: ⚠ WARNING — DESTDIR STAGING paths (${OUTPUT_DIR}) baked into installed TEXT files." >&2
  echo "            This is a RELOCATION DEFECT — the next rung's stage0 would carry a dead path." >&2
  echo "            Non-fatal here to avoid false-failing a 20h build, but MUST be fixed before sealing:" >&2
  echo "${hits_o}" >&2
else
  echo "R191-SWEEP: clean of staging paths (relocatable)" >&2
fi

# ============================================================================================
# P5 — FUNCTIONAL GATES.  Run the INSTALLED binaries from ${OUTPUT_DIR}, AFTER install.
#
# A --version gate is BANNED (the R5 scar).  The load-bearing gate is GATE-3: ten independent std
# constructs whose exit code is their computed SUM (42), never a literal — a compiler that
# miscompiled a comparison into a constant cannot manufacture it.  GATE-4 (proc-macro dylib
# dlopen'd + expanded) and GATE-5 (cargo DRIVES a build of a proc-macro crate + a #[derive]
# consumer) are the highest-value for a CHAIN rung, because the NEXT rung's x.py is saturated with
# derives and is driven entirely by cargo — a rustc that passes only GATE-3 but cannot dlopen a
# proc-macro or be driven by cargo would fail ~hours into rung 3 and be misdiagnosed.
#
# The gate .rs are heredoc'd inline so this recipe is self-contained (no Local-dep read that could
# be missing).  gatelib.rs / gatestd.rs / gate_pm.rs / gate_pm_use.rs are ALSO shipped in this dir
# as human-readable AUDIT copies — the inline bodies below are their verbatim source of truth.
#
# `set -e` would abort before a bare assert, so every gated command is rc-captured.
# The installed rustc is a real ELF with rpath $ORIGIN/../lib, so running ${DST}/bin/rustc directly
# finds librustc_driver.so; libLLVM.so is found in /usr/lib (the llvm dep, present at build time).
# ============================================================================================
RUSTC="${DST}/bin/rustc"
CARGO="${DST}/bin/cargo"
RLIB="${DST}/lib/rustlib/${TRIPLE}/lib"
G="${BUILDROOT}/gate"; mkdir -p "${G}"

# --- GATE-1: identity (cheap, anti-ambient; explicitly NOT the functional gate) -------------
# channel="stable" => a clean `rustc 1.91.1 (...)` with NO -mrustc suffix (contrast RUNG 1).
set +e; RV="$("${RUSTC}" --version 2>&1)"; rc=$?; set -e
[ ${rc} -eq 0 ] || { echo "R191-GATE-1: FAIL (installed rustc did not execute, rc=${rc}) — ${RV}" >&2; exit 1; }
echo "${RV}" | grep -qF "${VERSION}" || {
  echo "R191-GATE-1: FAIL — rustc --version = '${RV}', expected to contain '${VERSION}'" >&2; exit 1; }
echo "R191-GATE-1: PASS (identity ${RV})" >&2

# --- GATE-2: rlib production + cross-crate read-back ---------------------------------------
cat > "${G}/gatelib.rs" <<'RSEOF'
pub trait Shape { fn area(&self) -> i64; }
pub struct Sq(pub i64);
impl Shape for Sq { fn area(&self) -> i64 { self.0 * self.0 } }
/// wrapping arithmetic so the result is a COMPUTED value, not a constant.
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
  echo "R191-GATE-2: FAIL (rc=${rc}) — could not emit an rlib." >&2; tail -40 "${G}/g2.log" >&2 || true; exit 1; }
echo "R191-GATE-2: PASS (emitted a non-empty rlib)" >&2

# --- GATE-3: TEN std constructs, compiled AND EXECUTED, computed sum == 42 -----------------
# Ported verbatim from mrustc-rustc-1.90.0/gate190.rs (version-agnostic edition-2015 Rust).
# 42 is never in the success path; it is the SUM of ten computed quantities.  Each construct has
# its own exit code (111-120) so a red gate NAMES the miscompiled path.  c4 dispatches ACROSS the
# crate boundary into GATE-2's rlib — proving the archive was read back, not merely written.
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
    // 114: CROSS-CRATE Box<dyn Trait> vtable dispatch into the rlib
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
    // 117: catch_unwind — UNWINDING through panic_unwind
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
[ ${rc} -eq 0 ] || { echo "R191-GATE-3: FAIL (rc=${rc}) — could not compile the gate program:" >&2; tail -60 "${G}/g3-compile.log" >&2 || true; exit 1; }
set +e; "${G}/gatestd"; rc=$?; set -e
case ${rc} in
  42) : ;;
  111) echo "R191-GATE-3: FAIL — iterator/closure/heap" >&2; exit 1 ;;
  112) echo "R191-GATE-3: FAIL — core::fmt / parse round-trip" >&2; exit 1 ;;
  113) echo "R191-GATE-3: FAIL — BTreeMap/HashMap" >&2; exit 1 ;;
  114) echo "R191-GATE-3: FAIL — CROSS-CRATE vtable dispatch into the rlib" >&2; exit 1 ;;
  115) echo "R191-GATE-3: FAIL — generics + FnMut capture" >&2; exit 1 ;;
  116) echo "R191-GATE-3: FAIL — Result + '?' + Option" >&2; exit 1 ;;
  117) echo "R191-GATE-3: FAIL — catch_unwind / UNWINDING" >&2; exit 1 ;;
  118) echo "R191-GATE-3: FAIL — checked/wrapping overflow" >&2; exit 1 ;;
  119) echo "R191-GATE-3: FAIL — f64 round-trip" >&2; exit 1 ;;
  120) echo "R191-GATE-3: FAIL — threads + Arc<Mutex>" >&2; exit 1 ;;
  139) echo "R191-GATE-3: FAIL — SIGSEGV (rc=139). Suspect an rlib/dylib std ABI mismatch." >&2; exit 1 ;;
  126|127) echo "R191-GATE-3: FAIL — rc=${rc}: bad interpreter or missing DSO (loader/rpath)" >&2; exit 1 ;;
  *)   echo "R191-GATE-3: FAIL — gate binary exited ${rc}, expected the computed 42" >&2; exit 1 ;;
esac
echo "R191-GATE-3: PASS (ten std constructs compiled, linked and RAN; computed 42)" >&2

# --- GATE-4: proc-macro built as a dylib, dlopen'd, expanded, RUN -> computed 42 -----------
cat > "${G}/gate_pm.rs" <<'RSEOF'
extern crate proc_macro;
use proc_macro::TokenStream;
#[proc_macro_derive(GateVal)]
pub fn gate_val(_input: TokenStream) -> TokenStream {
    // 13 is produced INSIDE a dylib rustc loaded and ran; it cannot appear by accident statically.
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
    let v = t.val();          // exists ONLY because the proc macro ran
    if v != 13 { std::process::exit(121); }
    std::process::exit((v * 3 + 3) as i32);  // 42, computed
}
RSEOF
set +e
( cd "${G}" && "${RUSTC}" --crate-type=proc-macro --crate-name=gate_pm -L "${RLIB}" gate_pm.rs -o libgate_pm.so ) >"${G}/g4-pm.log" 2>&1
rc=$?; set -e
if [ ${rc} -ne 0 ]; then
  echo "R191-GATE-4: FAIL (rc=${rc}) — could not build a proc-macro crate; this rustc cannot serve as rung 3's stage0 (x.py is saturated with derives)." >&2
  ls -la "${RLIB}" | grep -i proc_macro >&2 || echo "             (no proc_macro artifact in ${RLIB})" >&2
  tail -40 "${G}/g4-pm.log" >&2 || true; exit 1
fi
set +e
( cd "${G}" && "${RUSTC}" -L "${RLIB}" --extern gate_pm="${G}/libgate_pm.so" gate_pm_use.rs -o gate_pm_use ) >"${G}/g4-use.log" 2>&1
rc=$?; set -e
[ ${rc} -eq 0 ] || { echo "R191-GATE-4: FAIL (rc=${rc}) — rustc could not LOAD and EXPAND the proc macro:" >&2; tail -40 "${G}/g4-use.log" >&2 || true; exit 1; }
set +e; "${G}/gate_pm_use"; rc=$?; set -e
[ ${rc} -eq 42 ] || { echo "R191-GATE-4: FAIL — proc-macro consumer exited ${rc}, expected 42" >&2; [ ${rc} -eq 121 ] && echo "             (121 = macro expanded but produced the wrong value)" >&2; exit 1; }
echo "R191-GATE-4: PASS (proc-macro crate built as a dylib, dlopen'd, expanded, and RAN)" >&2

# --- GATE-5: cargo DRIVES a build of a proc-macro crate + a #[derive] consumer -> 42 -------
# The truest "is this a valid x.py stage0" proof: rung 3's x.py is cargo-driven AND derive-heavy,
# so this single gate exercises BOTH surfaces together.  Zero registry deps -> no vendor, no
# network is even conceivable.
CW="${G}/cargows"
mkdir -p "${CW}/pmderive/src" "${CW}/app/src"
cat > "${CW}/pmderive/Cargo.toml" <<'EOF'
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
[ ${rc} -eq 0 ] || { echo "R191-GATE-5: FAIL (rc=${rc}) — cargo could not drive a proc-macro + derive build:" >&2; tail -50 "${G}/g5.log" >&2 || true; exit 1; }
set +e; "${CW}/target/release/gateapp"; rc=$?; set -e
[ ${rc} -eq 42 ] || { echo "R191-GATE-5: FAIL — cargo-built binary exited ${rc}, expected 42" >&2; exit 1; }
echo "R191-GATE-5: PASS (cargo built a proc-macro crate + a #[derive] consumer, and the binary RAN; computed 42)" >&2

# --- GATE-6: provenance/interp + offline re-assert ----------------------------------------
INTERP="$(readelf -l "${DST}/bin/rustc" 2>/dev/null | grep -o '/[^]]*ld-linux[^]]*' | head -1 || true)"
case "${INTERP}" in
  */ld-linux-*) echo "R191-GATE-6: rustc interp = ${INTERP}" >&2 ;;
  *) echo "R191-GATE-6: FAIL — rustc has no recognizable glibc interpreter (got '${INTERP}')" >&2; exit 1 ;;
esac
if [ -e "${BUILDROOT}/NETWORK-TRIPWIRE" ]; then
  echo "r191: FATAL a network fetch was attempted during the gate phase:" >&2; cat "${BUILDROOT}/NETWORK-TRIPWIRE" >&2; exit 1
fi
echo "R191-GATE-6: PASS (glibc interp; network tripwire clean after all gates)" >&2

# ============================================================================================
# P6 — BYTE SEAL — self-arming, exactly like mrustc-rustc-1.90.0/build.sh's seal.
# Ships UNPINNED: not expected 2-run byte-identical on the first attempt (LLVM VC-rev + the cargo
# metadata-hash surface are untriaged).  A second build here costs HOURS, so two-run comparison
# means two CS builds, not one build doing it twice.  Sealing is a DATA edit to the .answers file.
# NOTE the seal pins bin/rustc (a REAL ELF here) + bin/cargo — contrast RUNG 1, which pinned
# rustc_binary because its bin/rustc was a regenerated shell wrapper.
# ============================================================================================
ANS="${BUILDROOT}/rustc-${VERSION}.answers"
if [ -f "${ANS}" ] && grep -Eq '^[0-9a-f]{64}  ' "${ANS}"; then
  if ( cd "${OUTPUT_DIR}" && sha256sum -c "${ANS}" ); then
    echo "R191-SEAL: PASS (byte-identical to the pinned answers)" >&2
  else
    echo "R191-SEAL: FAIL (output drifted from rustc-${VERSION}.answers)" >&2; exit 1
  fi
else
  echo "R191-SEAL: NOT SEALED — no pins present. This rung is GREEN, not SEALED." >&2
fi

echo "R191: ALL GATES PASSED — rustc ${VERSION} installed at ${PREFIX}, ready as rung 3's stage0." >&2
