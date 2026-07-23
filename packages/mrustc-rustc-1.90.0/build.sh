#!/bin/sh
# ============================================================================================
# build.sh — rustc 1.90.0 built by the SIGNED packages/mrustc, on our seed-rooted ladder.
# RUNG 1 of 5 toward deleting packages/rust's unattested seed tarballs.  See build.ncl.
#
# Phases:
#   P0   preconditions   — every anchor asserted BY NAME before anything is built
#   P0b  offline harness — curl/wget fail-shut; git allows only LOCAL probes (rev-parse
#        HEAD/--git-dir/--show-toplevel, --version); any fetch verb is a hard tripwire
#   P1   unpack mrustc tree as DATA + sysroot harness + logging compiler wrappers
#   P2   rustc source     — pre-place tarball, let MAKE extract+patch, then our two patches
#   P3   LLVM via cmake   — pinned CC/CXX, the single biggest silent-provenance hole
#   P4   minicargo.mk     — LIBS -> output-1.90.0/rustc -> output-1.90.0/cargo
#   P5   run_rustc        — stages 1-4 (optimised rustc + full std + cargo)
#   P6   install          — private versioned prefix + the ABSOLUTE-PATH REWRITE
#   P7   gates            — FUNCTIONAL, run from ${OUTPUT_DIR}, AFTER install
#   P8   byte seal        — self-arming
#
# Every assertion is fail-shut with a NAMED message.  This rung has never been built in CS and
# runs for many hours; the first failure must be diagnosable from one log read, not a bisect.
# ============================================================================================
set -ex

VERSION="${MINIMAL_ARG_VERSION:-1.90.0}"
MRUSTC_VERSION="${MINIMAL_ARG_MRUSTC_VERSION:-0.12.0}"
MRUSTC_COMMIT="${MINIMAL_ARG_MRUSTC_COMMIT:-2d14b09a7e75166bec4413f48f61e3b3cd4de8ca}"

BUILDROOT="$(pwd)"
MTAR="mrustc-${MRUSTC_VERSION}.tar"
MSRC="${BUILDROOT}/mrustc-${MRUSTC_VERSION}"
RTAR="rustc-${VERSION}-src.tar.gz"
RSRC="rustc-${VERSION}-src"          # relative to ${MSRC}; minicargo.mk hardcodes this shape
OUTDIR="output-${VERSION}"

# Re-assert both Source shas here so a mirror swap cannot slip past the fetcher silently.
# Defence in depth, not a substitute for the Source sha256 in build.ncl.
MTAR_SHA=1ad6521c90e47754c5e13bd9abd183f4cd953eb9faa8a25e7b104b6ffe701512
RTAR_SHA=799a9f9cba4ed5351e071048bcf6b5560755d9009648def33a407dd4961f9b7e

TRIPLE=x86_64-unknown-linux-gnu
CCTRIPLE=x86_64-linux-gnu
TARGET_VER=1.90                      # NOT 1.90.0 — src/main.cpp:990-991 exit(1)s on unknown
GCC_VERSION=15.2.0
SR=/usr/lib/glibc-bedrock-2.42       # B4 versioned sysroot
LOADER="${SR}/lib/ld-linux-x86-64.so.2"

MR=/usr/bin/mrustc                   # from packages/mrustc's rootfs
MC=/usr/bin/minicargo
ZEROLEN=/usr/share/mrustc/patches/archive-zerolen-skip.sh

DST="${OUTPUT_DIR}/usr/lib/mrustc-rust-${VERSION}"

JOBS="$(nproc 2>/dev/null || echo 4)"

# ============================================================================================
# P0 — PRECONDITIONS.  Assert the ANCHOR, not just "a compiler".
# ============================================================================================
BGCC="$(command -v gcc || true)"
BGXX="$(command -v g++ || command -v ${CCTRIPLE}-g++ || true)"
[ -n "${BGCC}" ] || { echo "r190 infra: B5 gcc not on PATH" >&2; exit 1; }
[ -n "${BGXX}" ] || { echo "r190 infra: B5 g++ not on PATH" >&2; exit 1; }

# packages/mrustc's list PLUS the four this scope adds.  A missing `patch` or `cmake` otherwise
# surfaces as an unnamed failure hours in.
for t in as ld ar ranlib objcopy strip readelf make sed grep tar sha256sum \
         patch cmake perl python3 pkg-config find cmp gzip; do
  command -v "$t" >/dev/null 2>&1 || { echo "r190 infra: '$t' not on PATH (needed at this scope; NOT in packages/mrustc's list)" >&2; exit 1; }
done

GXXVER="$("${BGXX}" -dumpversion 2>/dev/null || echo unknown)"
[ "${GXXVER}" = "${GCC_VERSION}" ] || {
  echo "r190 infra: g++ -dumpversion = '${GXXVER}', expected '${GCC_VERSION}' (gcc-15.2.0-glibc, B5)." >&2
  echo "            Refusing to build: an unexpected host compiler makes this rung meaningless." >&2
  exit 1; }

# B4 sysroot
[ -e "${SR}/lib/libc.so" ]     || { echo "r190 infra: B4 sysroot missing at ${SR} (libc.so)" >&2; exit 1; }
[ -f "${SR}/lib/crt1.o" ]      || { echo "r190 infra: B4 startfiles missing (crt1.o)" >&2; exit 1; }
[ -f "${SR}/lib/Scrt1.o" ]     || { echo "r190 infra: B4 PIE startfiles missing (Scrt1.o)" >&2; exit 1; }
[ -e "${LOADER}" ]             || { echo "r190 infra: B4 loader missing at ${LOADER}" >&2; exit 1; }
[ -f "${SR}/include/stdio.h" ] || { echo "r190 infra: B4 headers missing at ${SR}/include" >&2; exit 1; }
[ -d "${SR}/include/linux" ]   || { echo "r190 infra: kernel UAPI not co-located in ${SR}/include" >&2; exit 1; }

# B5 C++ runtime + headers.  LLVM is a large C++ program; this is not optional here.
CB="/usr/include/c++/${GCC_VERSION}"
[ -d "${CB}" ] || { echo "r190 infra: B5 C++ headers missing at ${CB}" >&2; exit 1; }
[ -f "${CB}/${CCTRIPLE}/bits/c++config.h" ] || { echo "r190 infra: B5 target C++ config missing" >&2; exit 1; }
ls /usr/lib/libstdc++.so.6* >/dev/null 2>&1 || { echo "r190 infra: B5 libstdc++.so.6 missing" >&2; exit 1; }
# mrustc's emitted C links `-l atomic` unconditionally (src/trans/target.cpp:424).
ls /usr/lib/libatomic.so*  >/dev/null 2>&1 || { echo "r190 infra: libatomic missing" >&2; exit 1; }
[ -f /usr/include/zlib.h ] || { echo "r190 infra: zlib.h missing" >&2; exit 1; }

# --- ★ THE ANCHOR: the SIGNED packages/mrustc binaries ------------------------------------
[ -x "${MR}" ] || { echo "r190 infra: ${MR} missing — packages/mrustc is THE anchor of this rung" >&2; exit 1; }
[ -x "${MC}" ] || { echo "r190 infra: ${MC} missing — packages/mrustc is THE anchor of this rung" >&2; exit 1; }
[ -x "${ZEROLEN}" ] || { echo "r190 infra: ${ZEROLEN} missing (packages/mrustc/build.sh:273 ships it)" >&2; exit 1; }

# THE identity assert, and it is LOAD-BEARING, not decorative.  `$(MRUSTC)` is prerequisite-only
# on every target this rung builds (measured: it appears in exactly ONE recipe line in the whole
# of minicargo.mk, :344, which we never build).  minicargo selects mrustc itself via
# os.cpp:419/:436/:468.  So this string — printed by the binary ABOUT ITSELF at src/main.cpp:1015
# — is the only thing pinning compiler identity on the hot path.
# (It is a SELF-assertion: mrustc.answers ships UNPINNED so no sha is available.  See build.ncl's
# honesty boundary.  Fixing that is cheap and belongs in packages/mrustc, not here.)
MRVV="$("${MR}" -vV 2>&1 || true)"
echo "${MRVV}" | grep -qF "commit-hash: ${MRUSTC_COMMIT}" || {
  echo "r190 infra: ${MR} does not report commit-hash ${MRUSTC_COMMIT}." >&2
  echo "            Got:" >&2; echo "${MRVV}" >&2
  echo "            Refusing to build against an unidentified mrustc." >&2
  exit 1; }
echo "R190-ANCHOR: mrustc identity OK (commit ${MRUSTC_COMMIT})" >&2

# ============================================================================================
# P0b — OFFLINE HARNESS.
#
# curl/wget: fail-shut, unconditionally.  Note that unlike at packages/mrustc's scope a REAL
# curl binary IS in this rootfs (packages/cmake imports ../curl/build.ncl), so the proof rests
# on PATH ORDER, not on absence.  We assert the shadowing actually took.
#
# git: allowed for EXACTLY `git rev-parse HEAD` and nothing else.  Rationale, measured over all
# 240 vendored build.rs (see build.ncl's GIT SURFACE block): three sites take a
# `git submodule update --init` branch that the .git markers in P2 suppress entirely, and four
# sites (wasm-bindgen-shared x3, cranelift-codegen) call a BARE `git rev-parse HEAD` that NO
# marker can suppress — there is no path to create.  `rev-parse HEAD` is a purely local ref
# lookup with zero network semantics, and every caller already handles its failure
# (`.output().ok()`, wasm-bindgen-shared-0.2.100/build.rs:14).  Allowing exactly that argv
# therefore removes a guaranteed 15-hour false positive WITHOUT permitting any network-capable
# git verb.  Anything else — clone/fetch/pull/remote/ls-remote/submodule — is a hard tripwire.
# DO NOT "simplify" this to `exit 0`: that deletes the tripwire's value for the remaining ~15h.
# ============================================================================================
STUBS="${BUILDROOT}/stubs"; mkdir -p "${STUBS}"
for t in curl wget; do
  cat > "${STUBS}/${t}" <<EOF
#!/bin/sh
echo "\$0 \$*" >> "${BUILDROOT}/NETWORK-TRIPWIRE"
echo "r190: FATAL — the build invoked '${t}', which must never happen offline" >&2
exit 1
EOF
  chmod 0755 "${STUBS}/${t}"
done

cat > "${STUBS}/git" <<EOF
#!/bin/sh
# Permit the PURELY-LOCAL git probes rustc 1.90.0 makes to stamp its version. Measured on the
# 2026-07-22 CS run: after a COMPLETE build (100%, 22/22 crates), run_rustc's version-stamp step
# invoked \`git --version\` and \`git rev-parse --git-dir\` and the tripwire fired at 49.5min. None
# of these touch the network -- they are the same class as \`rev-parse HEAD\`. Allow exactly:
#   rev-parse HEAD | rev-parse --git-dir | rev-parse --show-toplevel | --version
# Everything else (clone/fetch/pull/remote/ls-remote/submodule) is still a hard tripwire.
case "\$1 \$2" in
  "rev-parse HEAD"|"rev-parse --git-dir"|"rev-parse --show-toplevel")
    echo "git \$*" >> "${BUILDROOT}/GIT-LOCAL.log"; exit 1 ;;  # real git's out-of-repo behaviour
esac
if [ "\$1" = "--version" ]; then
  echo "git \$*" >> "${BUILDROOT}/GIT-LOCAL.log"; echo "git version 0.0.0-bedrock-stub"; exit 0
fi
echo "git \$*" >> "${BUILDROOT}/NETWORK-TRIPWIRE"
echo "r190: FATAL — the build invoked git with a non-local argv: \$*" >&2
exit 1
EOF
chmod 0755 "${STUBS}/git"

PATH="${STUBS}:${PATH}"; export PATH
[ "$(command -v curl)" = "${STUBS}/curl" ] || {
  echo "r190: FATAL the curl stub is NOT shadowing the real curl (packages/cmake pulls one in)." >&2
  echo "      command -v curl = $(command -v curl)" >&2; exit 1; }
[ "$(command -v git)" = "${STUBS}/git" ] || {
  echo "r190: FATAL the git stub is NOT first on PATH" >&2; exit 1; }

# Belt and braces, all zero-diff and all expected NEVER to fire — which is what makes them good
# asserts.  CARGO_NET_OFFLINE turns any attempted fetch into a hard error rather than a hang.
# GIT_CEILING_DIRECTORIES stops repository discovery walking OUT of the build root: without it,
# "git fails locally" is a property of the ambient filesystem, not of this design.
export CARGO_NET_OFFLINE=true
export GIT_CEILING_DIRECTORIES="${BUILDROOT}"
export GIT_CONFIG_NOSYSTEM=1
export GIT_TERMINAL_PROMPT=0

# AMBIENT-CONFIG HAZARD: cargo's search_stop_path is None by default, so its config walk ascends
# to `/` looking for .cargo/config[.toml].  A stray file planted by another package could
# override [source.crates-io] and silently re-enable the network.  Fail shut.
d="${BUILDROOT}"
while [ "${d}" != "/" ] && [ -n "${d}" ]; do
  [ -e "${d}/.cargo" ] && { echo "r190: FATAL ambient .cargo/ found at ${d} — cargo would merge it" >&2; exit 1; }
  d="$(dirname "${d}")"
done
[ -e "/.cargo" ] && { echo "r190: FATAL ambient /.cargo/ present" >&2; exit 1; }
unset d

# ============================================================================================
# P1 — UNPACK THE mrustc TREE AS DATA + SYSROOT HARNESS
# ============================================================================================
have="$(sha256sum < "${MTAR}" | cut -d' ' -f1)"
[ "${have}" = "${MTAR_SHA}" ] || { echo "r190: FATAL mrustc tarball sha ${have} != ${MTAR_SHA}" >&2; exit 1; }
have="$(sha256sum < "${RTAR}" | cut -d' ' -f1)"
[ "${have}" = "${RTAR_SHA}" ] || { echo "r190: FATAL rustc tarball sha ${have} != ${RTAR_SHA}" >&2; exit 1; }

tar --no-same-owner -xf "${MTAR}"
[ -d "${MSRC}" ] || { echo "r190: FATAL mrustc tarball did not unpack to ${MSRC}/" >&2; exit 1; }

# The nine tree-data items this rung consumes.  All verified present at ${MRUSTC_COMMIT}.
# We NEVER run `make -f Makefile all` — the binaries come from the signed package.
for f in minicargo.mk rust-version rustc-${VERSION}-src.patch rustc-${VERSION}-overrides.toml \
         script-overrides/stable-${VERSION}-linux lib/libproc_macro \
         run_rustc/Makefile run_rustc/rustc_proxy.sh samples/hello.rs; do
  [ -e "${MSRC}/${f}" ] || { echo "r190: FATAL mrustc tree data missing: ${f}" >&2; exit 1; }
done
# minicargo.mk:16-17 reads this; if it ever stops being 1.29.0 the OUTDIR_SUF auto-derivation
# changes shape and we would silently build the wrong thing.
grep -qx '1.29.0' "${MSRC}/rust-version" || {
  echo "r190: FATAL mrustc rust-version is not 1.29.0 — OUTDIR_SUF derivation assumptions broken" >&2; exit 1; }

# --- B4 libc.so linker-script fixup (verbatim from gcc-15.2.0-glibc/build.sh:53-58) ---------
FIXLIB="${BUILDROOT}/glibc-fixlib"; mkdir -p "${FIXLIB}"
sed -E "s@[^ ()]*/(libc\.so\.6|libc_nonshared\.a|ld-linux-x86-64\.so\.2)@${SR}/lib/\1@g" \
  "${SR}/lib/libc.so" > "${FIXLIB}/libc.so"
grep -q '/build/output' "${FIXLIB}/libc.so" && { echo "r190 infra: libc.so fixup failed" >&2; exit 1; }

GIX="$("${BGXX}" -print-file-name=include)"
[ -f "${GIX}/stdint.h" ] || { echo "r190 infra: gcc internal headers not at '${GIX}'" >&2; exit 1; }

# Single-writer include discipline: /usr/include is written by multiple deps through an
# UNORDERED HashSet with first-writer-wins hardlinks, so relying on its contents is a per-run
# coin flip.  Copy what we need.  This scope needs more than packages/mrustc's zlib pair.
ZINC="${BUILDROOT}/zinc"; mkdir -p "${ZINC}"
cp /usr/include/zlib.h /usr/include/zconf.h "${ZINC}/"

CXXINC="-nostdinc -nostdinc++ -isystem ${CB} -isystem ${CB}/${CCTRIPLE} -isystem ${CB}/backward -isystem ${GIX} -isystem ${ZINC} -isystem ${SR}/include"
CINC="-nostdinc -isystem ${GIX} -isystem ${ZINC} -isystem ${SR}/include"

# ORDERING FIX vs packages/mrustc/build.sh:154-174.  There, ALL link flags are APPENDED, so
# -L${FIXLIB} lands LAST on the ld command line.  At mrustc's scope nothing else passed -L so
# the comment "-L${FIXLIB} FIRST" was true in effect.  At THIS scope rustc and cargo pass many
# -L directories and ld searches -L in command-line order, so an appended fixup silently stops
# being first the moment an earlier -L dir contains a libc.so.  Split: search paths PREPEND,
# -Wl options APPEND.
LPRE="-L${FIXLIB} -B${SR}/lib -L${SR}/lib -L/usr/lib"
LPOST="-Wl,--dynamic-linker=${LOADER} -Wl,-rpath,${SR}/lib:/usr/lib -Wl,--build-id=none"

WRAP="${BUILDROOT}/wrap"; mkdir -p "${WRAP}"

# Both wrappers LOG.  GATE-5 asserts both logs are non-empty and that the C++ log contains
# llvm-project translation units — the only machine-checkable statement that the largest
# compilation unit in this rung was built by OUR seed-rooted g++ (see minicargo.mk:301).
cat > "${WRAP}/bedrock-cc" <<EOF
#!/bin/sh
echo "cc \$*" >> "${BUILDROOT}/ccwrap.log"
case " \$* " in
  *" -c "*) exec "${BGCC}" ${CINC} ${LPRE} "\$@" ;;
esac
exec "${BGCC}" ${CINC} ${LPRE} "\$@" ${LPOST}
EOF
cat > "${WRAP}/bedrock-c++" <<EOF
#!/bin/sh
echo "c++ \$*" >> "${BUILDROOT}/cxxwrap.log"
case " \$* " in
  *" -c "*) exec "${BGXX}" ${CXXINC} ${LPRE} "\$@" ;;
esac
exec "${BGXX}" ${CXXINC} ${LPRE} "\$@" ${LPOST}
EOF
chmod 0755 "${WRAP}/bedrock-cc" "${WRAP}/bedrock-c++"

CCW="${WRAP}/bedrock-cc"
CXXW="${WRAP}/bedrock-c++"

# MRUSTC_CCACHE must stay UNSET (src/trans/codegen_c.cpp:1491); build-1.90.0.sh:5 opts into it
# when ccache is on PATH, which would be a hermeticity hole.
unset MRUSTC_CCACHE CFLAGS CXXFLAGS LDFLAGS RUSTFLAGS 2>/dev/null || true

# Runtime knobs.  MRUSTC_TARGET_VER is FAIL-OPEN when unset (src/main.cpp:995 only WARNS and
# silently falls back to 1.29 mode) so it must be exported before anything runs.
export MRUSTC_TARGET_VER="${TARGET_VER}"
# Make mrustc selection EXPLICIT rather than sibling-implicit (os.cpp:419 beats :436/:468).
export MRUSTC_PATH="${MR}"
export CC="${CCW}"
export CXX="${CXXW}"
export CC_x86_64_linux_gnu="${CCW}"   # takes priority over CC (codegen_c.cpp:1284-1292)

# 2026-07-22: the rustc mrustc BUILDS invokes a linker named `cc` by default (rustc's built-in
# default is the literal "cc"; run_rustc/Makefile:172 links samples/hello.rs with no -C linker=).
# The hermetic sandbox has `gcc`, not `cc`, so the run_rustc smoke test died with
#     error: linker `cc` not found (os error 2)
# after a full 37-minute build that otherwise SUCCEEDED (rustc built its own sysroot; the
# archive.rs zero-length-mmap bug did NOT bite -- "failed to map object file" appears 0x).
# Put `cc`/`c++` on PATH aliased to the SAME bedrock wrapper, so the built rustc's default linker
# resolves to our pinned gcc inside the sandbox rather than to a name that does not exist.
ln -sf "${CCW}" "${WRAP}/cc"
ln -sf "${CXXW}" "${WRAP}/c++"
PATH="${WRAP}:${PATH}"; export PATH
command -v cc >/dev/null 2>&1 || { echo "mrustc-1.90.0: FATAL cc alias not on PATH" >&2; exit 1; }

# Command-line variables, passed to EVERY make invocation.  Command line beats both `?=` and
# `:=`, and propagates to sub-makes via MAKEFLAGS (which matters: run_rustc/Makefile:127-132
# re-enters `$(MAKE) -C ../ -f minicargo.mk`).
#   V=          — un-silence recipes.  run_rustc/Makefile:115 defaults V to `@`; on a 20h build
#                 we want the commands in the log.
#   PARLEVEL    — minicargo.mk:32 and run_rustc/Makefile:16 BOTH default it to 1.  Left alone
#                 this build is serial: a wall-clock blocker, not a correctness one.
MKV="RUSTC_VERSION=${VERSION} OUTDIR_SUF=-${VERSION} MRUSTC=${MR} MINICARGO=${MC} \
CC=${CCW} CXX=${CXXW} PARLEVEL=${JOBS} V="

cd "${MSRC}"

# ============================================================================================
# P2 — RUSTC SOURCE: pre-place, let MAKE extract, then apply BOTH patches.
#
# The tarball must sit at the mrustc TREE ROOT under exactly the name minicargo.mk:220 builds.
# Its rule (:221-224) has NO prerequisites, so an existing file is unconditionally up to date
# and the `curl` recipe at :224 CANNOT fire.  (The folklore reason — "make builds a missing
# prereq that has a rule" — describes the wrong mechanism and would send someone to fix the
# wrong thing.)  Let MAKE do the extraction: hand-untarring without also creating the
# `extracted` and `dl-version` stamps sends make back into the extract rule.
# ============================================================================================
ln "${BUILDROOT}/${RTAR}" "./${RTAR}" 2>/dev/null \
  || mv "${BUILDROOT}/${RTAR}" "./${RTAR}" 2>/dev/null \
  || cp "${BUILDROOT}/${RTAR}" "./${RTAR}"
[ -f "./${RTAR}" ] || { echo "r190: FATAL could not place ${RTAR} at the mrustc tree root" >&2; exit 1; }

# minicargo.mk:187 RUSTCSRC -> :228 dl-version -> :225 extracted -> :221 tarball.
# :229 runs `cd rustc-1.90.0-src && patch -p0 < ../rustc-1.90.0-src.patch` (5 hunks, all in
# compiler/*.rs; measured: it does NOT touch archive.rs, so there is no conflict below).
make -f minicargo.mk ${MKV} RUSTCSRC
[ -d "${RSRC}/vendor" ] || { echo "r190: FATAL ${RSRC}/vendor absent after extraction" >&2; exit 1; }
[ -f "${RSRC}/src/llvm-project/llvm/CMakeLists.txt" ] || {
  echo "r190: FATAL ${RSRC}/src/llvm-project/llvm/CMakeLists.txt absent — minicargo.mk:309 has no rule for it" >&2; exit 1; }

# --- the two submodule .git markers ---------------------------------------------------------
# MEASURED over all 240 vendored build.rs: exactly three sites guard on a `.git` marker the
# tarball does not ship (0 `.git` entries in 279266 files) and therefore take an unconditional
# `git submodule update --init` branch.  Creating an empty marker suppresses the invocation
# entirely and keeps the git stub fail-shut for every other verb.
#
# Checksum-safe: cargo's DirectorySource::verify iterates ONLY the files listed in
# .cargo-checksum.json, so an unlisted EXTRA file is never detected.  The converse is the rule
# that matters for anyone adding future patches: NEVER EDIT AN EXISTING FILE UNDER vendor/ —
# that fails with "the listed checksum of `X` has changed".  (archive-zerolen-skip.sh is safe
# only because it targets an IN-TREE file, not a vendored crate.)
#
# libgit2-sys is deliberately ABSENT from this list: it guards on `libgit2/src`, which DOES ship
# (404 entries in each of 0.18.0 and 0.18.2), so it never fires.  A `.git` marker there would be
# cargo-cult.  Do not derive this list by pattern-matching on `.git`; derive it by READING each
# guard at the pinned version.
for sub in "vendor/curl-sys-0.4.82+curl-8.14.1/curl" \
           "vendor/curl-sys-0.4.79+curl-8.12.0/curl" \
           "vendor/libssh2-sys-0.3.1/libssh2"; do
  # Assert the PARENT by exact name first: a silent `mkdir -p` over a drifted version would
  # rebuild the bogus path and put us right back at a multi-hour false positive.
  [ -d "${RSRC}/${sub}" ] || {
    echo "r190: FATAL expected vendored submodule dir missing: ${sub}" >&2
    echo "      The 1.90.0 lockfile pins these versions.  If upstream drifted, RE-DERIVE the" >&2
    echo "      marker list by reading each vendor/*/build.rs guard.  Do NOT mkdir -p blindly." >&2
    exit 1; }
  [ -e "${RSRC}/${sub}/.git" ] || : > "${RSRC}/${sub}/.git"
done

# --- the landed strand ----------------------------------------------------------------------
# Applied AFTER minicargo.mk:229's own patch and BEFORE output-1.90.0/rustc is built, per the
# script's own header.  Verified against the real staged source: the needle occurs EXACTLY ONCE
# (archive.rs:474), the enum shape is exactly as assumed (`File(PathBuf)` at :337-340), and the
# mmap it guards is at :487-490, INSIDE that loop.
#
# CORRECTION to the script's header comment, worth knowing when reading a 20h log: memmap2 does
# NOT abort at the mmap.  archive.rs:490 is `.map_err(...)?` — an Err.  The SIGABRT arrives
# downstream via build_inner -> build() -> emit_fatal(ArchiveBuildFailure) -> FatalError panic ->
# abort in a rustc without working unwinding.  So the string to grep for is
# "failed to map object file" / ArchiveBuildFailure, NOT a bare SIGABRT.
#
# Two steps in the script's recorded VM ordering are deliberately SKIPPED, not forgotten:
# "move aside run_rustc/output-*/prefix-s" and "touch archive.rs".  Both are incremental-rebuild
# hygiene; a cold sandbox has no prior outputs, and `sed -i` already gives the file a now-mtime
# against a tree carrying 2025 mtimes.
"${ZEROLEN}" "${RSRC}"
grep -q 'ZEROLEN-SKIP' "${RSRC}/compiler/rustc_codegen_ssa/src/back/archive.rs" || {
  echo "r190: FATAL archive-zerolen-skip.sh reported success but the marker is absent" >&2; exit 1; }

# ============================================================================================
# P3 — LLVM (cmake).  THE BIGGEST SILENT-PROVENANCE HOLE IN THE RUNG.
#
# minicargo.mk:301 passes CMAKE_CXX_COMPILER="$(CXX)" CMAKE_C_COMPILER="$(CC)".  CXX and CC are
# GNU make BUILTINS (g++ / cc).  minicargo.mk assigns NEITHER, so if we do not override them,
# LLVM — the largest compilation unit in this rung — is built by whatever is first on PATH and
# NOTHING FAILS.  You get a green build whose provenance claim is unearned.  We pass both on the
# make COMMAND LINE (in ${MKV}) and PROVE it in GATE-5 via cxxwrap.log.
# packages/mrustc never covered this: its build.sh:229 pinned CXX for its own make only.
#
# Built as an explicit phase rather than letting the :282 prerequisite pull it in, purely so the
# log has a clean boundary.  LLVM_CONFIG is `:=` at minicargo.mk:150 — command-line overridable
# only — which is the escape hatch if a separately-attested LLVM ever exists.  We do not use it.
# ============================================================================================
make -f minicargo.mk ${MKV} "${RSRC}/build/bin/llvm-config"
[ -x "${RSRC}/build/bin/llvm-config" ] || { echo "r190: FATAL llvm-config not produced" >&2; exit 1; }

# ============================================================================================
# P4 — minicargo.mk: LIBS -> rustc -> cargo
#
# Offline here is STRUCTURAL, not conventional: minicargo cannot fetch (manifest.h:210
# has_git()==false; manifest.cpp:984-992 git deps hit eh.todo(); zero socket/http/popen
# primitives) and vendor/ coverage of the locks is 100% measured.
#
# MMIR must stay EMPTY: tools/minicargo/build.cpp:1186 hardcodes an absolute developer path
# /home/tpg/Projects/mrustc/bin/standalone_miri, reachable only under MMIR.
#
# NOT `make test` / `make local_tests` (build-1.90.0.sh:9-10): those need bin/testrunner and, at
# the DEFAULT version, curl rustc-1.29.0-src.tar.gz — which is exactly the rule that produced
# packages/mrustc's third CS failure.
# NOT LIBGIT2_SYS_USE_PKG_CONFIG=1 (build-1.90.0.sh:23): we have no system libgit2, and the
# vendored path is fine because libgit2/src ships.
# ============================================================================================
make -f minicargo.mk ${MKV} LIBS
make -f minicargo.mk ${MKV} RUSTC_INSTALL_BINDIR=bin "${OUTDIR}/rustc"
[ -x "${OUTDIR}/rustc" ] || { echo "r190: FATAL ${OUTDIR}/rustc not produced" >&2; exit 1; }
make -f minicargo.mk ${MKV} "${OUTDIR}/cargo"
[ -x "${OUTDIR}/cargo" ] || { echo "r190: FATAL ${OUTDIR}/cargo not produced" >&2; exit 1; }

# Cheap smoke ONLY, explicitly NOT a gate.  build-1.90.0.sh:20 runs
# `rustc samples/no_core-1_90.rs`, which is COMPILE-ONLY, and even if executed its lang_start
# returns a LITERAL 0 — vacuous by construction.  The real gates are in P7, after install.
"./${OUTDIR}/rustc" --version

# ============================================================================================
# P5 — run_rustc: stage 1 (std via minicargo) -> stage 2 (full std via cargo) -> stage 3
#      (optimised rustc) -> stage 4 (std matching its ABI) -> cargo.
#
# THIS is where archive-zerolen-skip.sh finally bites: run_rustc/Makefile:162 is the first place
# the mrustc-BUILT rustc is RUN (MRUSTC_PATH=$(BINDIR_S)rustc), and ArArchiveBuilder is rustc's
# own Rust code.  minicargo.mk only ever BUILDS that rustc.
#
# Offline here rests on ONE generated file: $(CARGO_HOME)config at run_rustc/Makefile:145-151,
# which points [source.crates-io] at [source.vendored-sources].  There is no --offline/--locked/
# --frozen on any live cargo line (the only --frozen is inside the commented-out TEST_BOOTSTRAP
# block at :264-269).  That is sufficient — measured: zero git+ entries in all four lockfiles
# and 100% vendor coverage — and CARGO_NET_OFFLINE=true is the exported belt-and-braces.
# Note the extension-less `config` filename is deprecated but still honoured by cargo 1.90.
#
# The MRUSTC/MINICARGO command-line vars are passed even though run_rustc never references
# MRUSTC: they propagate through MAKEFLAGS to the `$(MAKE) -C ../ -f minicargo.mk` re-entries at
# :127-132.  Those re-entries should be no-ops (the targets already exist as files with
# prerequisite-free rules), but if they ever DO fire without the overrides they would trigger the
# .PHONY self-rebuild of mrustc — silently discarding the signed anchor.
# ============================================================================================
make -C run_rustc ${MKV}
RRP="run_rustc/${OUTDIR}/prefix"
[ -x "${RRP}/bin/rustc" ]        || { echo "r190: FATAL run_rustc did not produce ${RRP}/bin/rustc" >&2; exit 1; }
[ -x "${RRP}/bin/rustc_binary" ] || { echo "r190: FATAL ${RRP}/bin/rustc_binary missing" >&2; exit 1; }
[ -x "${RRP}/bin/cargo" ]        || { echo "r190: FATAL ${RRP}/bin/cargo missing" >&2; exit 1; }

# --- offline tripwire, checkpoint 1 --------------------------------------------------------
if [ -e "${BUILDROOT}/NETWORK-TRIPWIRE" ]; then
  echo "r190: FATAL the build attempted a network fetch:" >&2
  cat "${BUILDROOT}/NETWORK-TRIPWIRE" >&2
  exit 1
fi
if [ -e "${BUILDROOT}/GIT-LOCAL.log" ]; then
  echo "R190-OFFLINE: NOTE — permitted local \`git rev-parse HEAD\` calls occurred:" >&2
  sort -u "${BUILDROOT}/GIT-LOCAL.log" >&2
  echo "              (expected 0; a non-zero count means minicargo's cfg gating admitted" >&2
  echo "               wasm-bindgen-shared.  Harmless — no network verb was permitted.)" >&2
fi
echo "R190-OFFLINE: PASS (no curl/wget, and no network-capable git verb, during the build)" >&2

# ============================================================================================
# P6 — INSTALL, WITH THE ABSOLUTE-PATH REWRITE.
#
# run_rustc/Makefile:227 bakes ABSOLUTE build-tree paths into the generated bin/rustc shell
# wrapper: it computes `d=$(dirname $0)` and then does NOT use it for LD_LIBRARY_PATH, writing
# $(abspath OUTDIR/prefix/lib) instead.  Post-install that path does not exist.  Same failure
# CLASS as the lean stage0 /proc/<pid>/exe bug — correct in the build environment, wrong
# everywhere else.  We REGENERATE the wrapper $0-relative rather than sed it, then sweep.
# ============================================================================================
mkdir -p "${DST}/bin" "${DST}/lib" "${OUTPUT_DIR}/usr/share/mrustc-rust-${VERSION}"
# Only bin/ and lib/ are artifacts.  $(PREFIX)cargo_home and $(PREFIX)tmp
# (run_rustc/Makefile:89, :205) are build scratch and are simply not copied.
cp -a "${RRP}/bin/." "${DST}/bin/"
cp -a "${RRP}/lib/." "${DST}/lib/"
# run_rustc/Makefile:259 builds hello_world into BINDIR; it is a test artifact, not a tool.
rm -f "${DST}/bin/hello_world"

cat > "${DST}/bin/rustc" <<'WRAPEOF'
#!/bin/sh
d="$(dirname "$0")"
LD_LIBRARY_PATH="${d}/../lib:${d}/../lib/rustlib/x86_64-unknown-linux-gnu/lib${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}" \
  exec "${d}/rustc_binary" "$@"
WRAPEOF
chmod 0755 "${DST}/bin/rustc"

# Fail shut on a surviving build path in any TEXT file in the installed tree.  A single missed
# absolute path is a rung-2 mystery, not a rung-1 one.
#
# `grep -I` (skip binaries) is LOAD-BEARING here, not a speed optimisation: rustc bakes source
# paths into DWARF, and we compile under ${BUILDROOT}/mrustc-0.12.0/, so every .rlib and every
# ELF legitimately contains that string.  A sweep without -I would fail-shut on debug info —
# benign, unfixable without -Cremap-path-prefix, and it would look exactly like a real bug.
# The failure this actually targets is a baked path in a generated SHELL SCRIPT, which is what
# run_rustc/Makefile:227 produces.
hits="$(find "${OUTPUT_DIR}" -type f -exec grep -I -l -F "${BUILDROOT}" {} + 2>/dev/null || true)"
if [ -n "${hits}" ]; then
  echo "r190: FATAL build-root paths survive in installed TEXT files:" >&2
  echo "${hits}" >&2
  exit 1
fi

cat > "${OUTPUT_DIR}/usr/share/mrustc-rust-${VERSION}/BUILDINFO" <<EOF
rustc-version: ${VERSION}
rustc-source-sha256: ${RTAR_SHA}
built-by: mrustc ${MRUSTC_VERSION} (commit ${MRUSTC_COMMIT}), consumed from packages/mrustc
mrustc-tarball-sha256: ${MTAR_SHA}
host-cc: gcc-15.2.0-glibc (B5), gcc/g++ ${GXXVER}
host-sysroot: ${SR} (glibc-bedrock-2.42, B4)
host-binutils: binutils-2.46-glibc
target: ${TRIPLE}
scope: LIBS + output-${VERSION}/{rustc,cargo} + run_rustc stages 1-4
patches-applied: rustc-${VERSION}-src.patch (mrustc, minicargo.mk:229), archive-zerolen-skip.sh
seal-status: see rustc-${VERSION}.answers
EOF

# ============================================================================================
# P7 — FUNCTIONAL GATES.  Run the INSTALLED binaries from ${OUTPUT_DIR}, AFTER install.
#
# Upstream's own checks are NOT sufficient and are not used as gates:
#   * build-1.90.0.sh:20 `rustc samples/no_core-1_90.rs` is COMPILE-ONLY, and the program's
#     lang_start returns a LITERAL 0 — vacuous even if executed.
#   * run_rustc/Makefile:259-263's hello_world is exit-status-only over
#     `fn main() { println!("Hello, world!"); }`.  stdout is neither captured nor compared, and
#     main returns () so the status is 0 unless the process dies.  Its real content is "does not
#     crash" — precisely the failure class these gates must go BEYOND.  It also fires inside the
#     build tree, BEFORE P6's rewrite, so it certifies a binary that by construction is not the
#     one that ships.
#
# `set -e` would abort before a bare assert, so every gated command is rc-captured.
# ============================================================================================
RUSTC="${DST}/bin/rustc"
CARGO="${DST}/bin/cargo"
RLIB="${DST}/lib/rustlib/${TRIPLE}/lib"
G="${BUILDROOT}/gate"; mkdir -p "${G}"

# --- GATE-1: identity (cheap, anti-ambient; explicitly NOT the functional gate) -------------
# run_rustc/Makefile:98 sets CFG_VERSION=$(RUSTC_VERSION)-stable-mrustc, so this string
# simultaneously proves the binary is OURS and that RUSTC_VERSION took (unset would have
# silently produced a 1.29.0 build).
set +e; RV="$("${RUSTC}" --version 2>&1)"; rc=$?; set -e
[ ${rc} -eq 0 ] || { echo "R190-GATE-1: FAIL (installed rustc did not execute, rc=${rc}) — ${RV}" >&2; exit 1; }
echo "${RV}" | grep -qF "${VERSION}-stable-mrustc" || {
  echo "R190-GATE-1: FAIL — rustc --version = '${RV}', expected to contain '${VERSION}-stable-mrustc'" >&2; exit 1; }
echo "R190-GATE-1: PASS (identity ${RV})" >&2

# --- GATE-2: rlib PRODUCTION — the ArArchiveBuilder path --------------------------------
# Emitting an rlib forces ArArchiveBuilder::build_inner to run: the exact code path that fails
# on a zero-length member and the exact reason archive-zerolen-skip.sh exists.  A single-binary
# gate would never touch it.
cp "${BUILDROOT}/gatelib.rs" "${G}/gatelib.rs"
set +e
( cd "${G}" && "${RUSTC}" --crate-type=rlib --crate-name=gatelib -L "${RLIB}" gatelib.rs -o libgatelib.rlib ) \
  >"${G}/g2.log" 2>&1
rc=$?
set -e
if [ ${rc} -ne 0 ]; then
  echo "R190-GATE-2: FAIL (rc=${rc}) — could not emit an rlib." >&2
  tail -40 "${G}/g2.log" >&2 || true
  grep -qE 'failed to map object file|ArchiveBuildFailure' "${G}/g2.log" && \
    echo "HINT: that is the ZERO-LENGTH-MEMBER wall.  archive-zerolen-skip.sh did not take." >&2
  exit 1
fi
[ -s "${G}/libgatelib.rlib" ] || { echo "R190-GATE-2: FAIL (rc=0 but no rlib produced)" >&2; exit 1; }
echo "R190-GATE-2: PASS (ArArchiveBuilder wrote a non-empty rlib)" >&2

# --- GATE-3: TEN std constructs, compiled AND EXECUTED, computed sum ----------------------
# The pass value 42 is never written in the success path: it is only ever the SUM of ten
# computed quantities.  A compiler that miscompiled a comparison into a constant cannot
# manufacture it.  Each construct ALSO has its own exit code so a red gate NAMES the miscompiled
# path.  c4 calls ACROSS the crate boundary into the rlib from GATE-2, which proves the archive
# was not just written but read back.
cp "${BUILDROOT}/gate190.rs" "${G}/gate190.rs"
set +e
( cd "${G}" && "${RUSTC}" -L "${RLIB}" --extern gatelib="${G}/libgatelib.rlib" gate190.rs -o gate190 ) \
  >"${G}/g3-compile.log" 2>&1
rc=$?
set -e
if [ ${rc} -ne 0 ]; then
  echo "R190-GATE-3: FAIL (rc=${rc}) — the installed rustc could not compile the gate program:" >&2
  tail -60 "${G}/g3-compile.log" >&2 || true
  exit 1
fi
set +e; "${G}/gate190"; rc=$?; set -e
case ${rc} in
  42) : ;;
  111) echo "R190-GATE-3: FAIL — iterator/closure/heap path (Vec+filter+map+sum != 165)" >&2; exit 1 ;;
  112) echo "R190-GATE-3: FAIL — core::fmt / String / str::parse round-trip" >&2; exit 1 ;;
  113) echo "R190-GATE-3: FAIL — BTreeMap/HashMap (Ord, hashing, OS entropy for RandomState)" >&2; exit 1 ;;
  114) echo "R190-GATE-3: FAIL — CROSS-CRATE Box<dyn Trait> vtable dispatch into the rlib" >&2; exit 1 ;;
  115) echo "R190-GATE-3: FAIL — generics + FnMut closure capture" >&2; exit 1 ;;
  116) echo "R190-GATE-3: FAIL — Result + '?' + Option combinators" >&2; exit 1 ;;
  117) echo "R190-GATE-3: FAIL — catch_unwind / UNWINDING through panic_unwind" >&2; exit 1 ;;
  118) echo "R190-GATE-3: FAIL — checked_add/wrapping_add overflow semantics" >&2; exit 1 ;;
  119) echo "R190-GATE-3: FAIL — f64 format + parse round-trip" >&2; exit 1 ;;
  120) echo "R190-GATE-3: FAIL — thread::spawn + join + Arc<Mutex<_>> (pthreads, TLS, atomics)" >&2; exit 1 ;;
  134) echo "R190-GATE-3: FAIL — SIGABRT (rc=134). Suspect the zero-length-member wall." >&2; exit 1 ;;
  139) echo "R190-GATE-3: FAIL — SIGSEGV (rc=139). Suspect an rlib/dylib std ABI mismatch." >&2; exit 1 ;;
  126|127) echo "R190-GATE-3: FAIL — rc=${rc}: bad interpreter or missing DSO (loader/rpath)" >&2; exit 1 ;;
  *)   echo "R190-GATE-3: FAIL — gate binary exited ${rc}, expected the computed 42" >&2; exit 1 ;;
esac
echo "R190-GATE-3: PASS (ten std constructs compiled, linked and RAN; computed 42)" >&2

# --- GATE-4: PROC MACROS + dylib std.  THE HIGHEST-VALUE GATE IN THIS RECIPE. -------------
# run_rustc/Makefile:218 (`cp $(LIBDIR_2)*.$(DYLIB_EXT) $(PREFIX)lib`) is the ONLY thing that
# produces dylib std.  If it silently produced nothing, or if proc_macro is missing from LIBDIR,
# or if rustc cannot dlopen a proc-macro .so, then GATE-3 and upstream's hello_world BOTH STILL
# PASS — they are statically linked and never load a dylib.  Rung 2's x.py would then die,
# because rustc's own bootstrap is saturated with derives, and that failure would surface ~20h
# into the NEXT rung and be misdiagnosed as an x.py problem.
#
# KEEP THIS FAIL-SHUT.  A rustc that cannot do proc macros is useless as rung 2's stage0, so the
# correct response to a red GATE-4 is to fix the sysroot feature set, NOT to soften the gate.
cp "${BUILDROOT}/gate_pm.rs" "${G}/gate_pm.rs"
cp "${BUILDROOT}/gate_pm_use.rs" "${G}/gate_pm_use.rs"
set +e
( cd "${G}" && "${RUSTC}" --crate-type=proc-macro --crate-name=gate_pm -L "${RLIB}" gate_pm.rs -o libgate_pm.so ) \
  >"${G}/g4-pm.log" 2>&1
rc=$?
set -e
if [ ${rc} -ne 0 ]; then
  echo "R190-GATE-4: FAIL (rc=${rc}) — could not build a proc-macro crate." >&2
  echo "             This rustc cannot serve as rung 2's stage0: x.py is saturated with derives." >&2
  echo "             Fix the run_rustc sysroot feature set (is proc_macro in ${RLIB}?)." >&2
  ls -la "${RLIB}" | grep -i proc_macro >&2 || echo "             (no proc_macro artifact in ${RLIB})" >&2
  tail -40 "${G}/g4-pm.log" >&2 || true
  exit 1
fi
set +e
( cd "${G}" && "${RUSTC}" -L "${RLIB}" --extern gate_pm="${G}/libgate_pm.so" gate_pm_use.rs -o gate_pm_use ) \
  >"${G}/g4-use.log" 2>&1
rc=$?
set -e
if [ ${rc} -ne 0 ]; then
  echo "R190-GATE-4: FAIL (rc=${rc}) — rustc could not LOAD and EXPAND the proc macro:" >&2
  tail -40 "${G}/g4-use.log" >&2 || true
  exit 1
fi
set +e; "${G}/gate_pm_use"; rc=$?; set -e
[ ${rc} -eq 42 ] || {
  echo "R190-GATE-4: FAIL — proc-macro consumer exited ${rc}, expected the computed 42" >&2
  [ ${rc} -eq 121 ] && echo "             (121 = the macro expanded but produced the wrong value)" >&2
  exit 1; }
echo "R190-GATE-4: PASS (proc-macro crate built as a dylib, dlopen'd, expanded, and RAN)" >&2

# --- GATE-5: cargo actually DRIVES a build (not a --version check) ------------------------
# Two crates with a path dependency, zero registry deps — so no vendor dir and no network is
# even conceivable.  Proves cargo parses a manifest, resolves, invokes rustc and links.
CW="${G}/cargows"
mkdir -p "${CW}/app/src" "${CW}/dep/src"
cat > "${CW}/dep/Cargo.toml" <<'EOF'
[package]
name = "gatedep"
version = "0.0.0"
edition = "2015"
EOF
cat > "${CW}/dep/src/lib.rs" <<'EOF'
pub fn triple(x: i64) -> i64 { x * 3 }
EOF
cat > "${CW}/app/Cargo.toml" <<'EOF'
[package]
name = "gateapp"
version = "0.0.0"
edition = "2015"

[dependencies]
gatedep = { path = "../dep" }
EOF
cat > "${CW}/app/src/main.rs" <<'EOF'
extern crate gatedep;
fn main() {
    let v = gatedep::triple(13) + 3; // 42, computed
    std::process::exit(v as i32);
}
EOF
set +e
( cd "${CW}/app" && CARGO_HOME="${CW}/home" RUSTC="${RUSTC}" \
    "${CARGO}" build --offline --release --target-dir "${CW}/target" ) >"${G}/g5.log" 2>&1
rc=$?
set -e
if [ ${rc} -ne 0 ]; then
  echo "R190-GATE-5: FAIL (rc=${rc}) — cargo could not drive a two-crate path-dependency build:" >&2
  tail -40 "${G}/g5.log" >&2 || true
  exit 1
fi
set +e; "${CW}/target/release/gateapp"; rc=$?; set -e
[ ${rc} -eq 42 ] || { echo "R190-GATE-5: FAIL — cargo-built binary exited ${rc}, expected the computed 42" >&2; exit 1; }
echo "R190-GATE-5: PASS (cargo resolved a path dep, invoked our rustc, linked, and the binary RAN)" >&2

# --- GATE-6: PROVENANCE, machine-checked --------------------------------------------------
# (a) our gcc did the C codegen and linking; (b) our g++ built LLVM — the assert that plugs
# minicargo.mk:301's silent CC/CXX hole, and the one packages/mrustc had no need for;
# (c) the shipped rustc really runs under the B4 loader.
[ -s "${BUILDROOT}/ccwrap.log" ] || {
  echo "R190-GATE-6: FAIL — ccwrap.log empty: nothing went through our pinned B5 gcc" >&2; exit 1; }
[ -s "${BUILDROOT}/cxxwrap.log" ] || {
  echo "R190-GATE-6: FAIL — cxxwrap.log empty: our B5 g++ compiled NOTHING." >&2
  echo "             minicargo.mk:301 reads the make BUILTIN \$(CXX) — LLVM was built by an" >&2
  echo "             ambient compiler and this rung's provenance claim is unearned." >&2
  exit 1; }
grep -q 'llvm-project' "${BUILDROOT}/cxxwrap.log" || {
  echo "R190-GATE-6: FAIL — no llvm-project translation unit in cxxwrap.log." >&2
  echo "             LLVM is the largest compile in this rung and it did not go through our g++." >&2
  exit 1; }
INTERP="$(readelf -l "${DST}/bin/rustc_binary" 2>/dev/null | grep -o '/[^]]*ld-linux[^]]*' | head -1 || true)"
[ "${INTERP}" = "${LOADER}" ] || {
  echo "R190-GATE-6: FAIL — rustc_binary interpreter = '${INTERP}', expected '${LOADER}'" >&2; exit 1; }
echo "R190-GATE-6: PASS (cc=$(wc -l < "${BUILDROOT}/ccwrap.log" | tr -d ' ') c++=$(wc -l < "${BUILDROOT}/cxxwrap.log" | tr -d ' ') invocations; LLVM via our g++; B4 loader)" >&2

# --- GATE-7: re-assert offline AFTER the gates ---------------------------------------------
# P5's check runs before any gate executes; a fetch attempted during P7 would otherwise pass
# unnoticed.  (cargo in GATE-5 is the realistic candidate.)
if [ -e "${BUILDROOT}/NETWORK-TRIPWIRE" ]; then
  echo "r190: FATAL a network fetch was attempted during the gate phase:" >&2
  cat "${BUILDROOT}/NETWORK-TRIPWIRE" >&2; exit 1
fi
echo "R190-GATE-7: PASS (network tripwire clean after all gates)" >&2

# ============================================================================================
# P8 — BYTE SEAL — self-arming, exactly as packages/mrustc/build.sh:389-399.
# Ships UNPINNED: this rung is NOT expected to be 2-run byte-identical on the first attempt
# (minicargo.mk:294-303 sets no LLVM_APPEND_VC_REV and no timestamp suppression; the four
# cargo-driven stages have their own metadata-hash surface).
# Deliberately NOT copied from packages/mrustc: its in-build determinism proof (build.sh:248-264).
# There a version.o rebuild costs seconds; here a second `make output-1.90.0/rustc` costs HOURS.
# ============================================================================================
ANS="${BUILDROOT}/rustc-${VERSION}.answers"
if grep -Eq '^[0-9a-f]{64}  ' "${ANS}"; then
  if ( cd "${OUTPUT_DIR}" && sha256sum -c "${ANS}" ); then
    echo "R190-SEAL: PASS (byte-identical to the pinned answers)" >&2
  else
    echo "R190-SEAL: FAIL (output drifted from rustc-${VERSION}.answers)" >&2
    exit 1
  fi
else
  echo "R190-SEAL: NOT SEALED — rustc-${VERSION}.answers carries no pins. This rung is GREEN, not SEALED." >&2
fi
