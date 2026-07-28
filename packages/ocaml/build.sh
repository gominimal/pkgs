#!/bin/sh
set -ex

case $(uname -m) in
  x86_64)  MARCH="-march=x86-64-v3"; LOADER_SO="ld-linux-x86-64.so.2" ;;
  aarch64) MARCH="-march=armv8-a";   LOADER_SO="ld-linux-aarch64.so.1" ;;
  *)       MARCH="";                 LOADER_SO="" ;;
esac

# ============================================================================================
# ★ BEDROCK SYSROOT HARNESS (issue #48) — build OCaml with the SEED-ROOTED compiler.
#
# Was: `../toolchain` (over ../gcc, which IMPORTS ITSELF — a self-hosting fixed point rooted in
# whatever gcc we already had).  Now: B5 gcc-15.2.0-glibc + B4 glibc-bedrock-2.42 +
# binutils-2.46-glibc, whose chain is hex0 -> ... -> gcc-10.4.0 -> R12 -> B5.
#
# ⚠ THE OCAML-SPECIFIC CONSTRAINT, and why this does NOT copy mrustc's wrapper approach:
# ./configure BAKES the C compiler and its flags into Makefile.config -> config.ml -> the
# installed ocamlopt, which RE-INVOKES them at runtime to link every native binary a user
# compiles.  A wrapper script under $BUILDROOT would not exist in a consumer's rootfs, so the
# installed ocamlopt would be silently broken.  Everything baked here must therefore be either a
# bare command resolved from PATH (`gcc`, supplied at runtime by gcc-15.2.0-glibc) or an
# ABSOLUTE path that still exists at runtime (the ${SR} sysroot, a declared runtime_dep).
# ============================================================================================
GCC_VERSION=15.2.0
SR=/usr/lib/glibc-bedrock-2.42          # B4 sysroot: headers + crt + libs + co-located UAPI
LOADER="${SR}/lib/${LOADER_SO}"

# --- P0 preconditions: assert the ANCHOR, not just "a compiler" ---------------------------
# An ambient gcc here would produce a green build that proves nothing about hex0-rooting.
BGCC="$(command -v gcc || true)"
[ -n "${BGCC}" ] || { echo "ocaml infra: B5 gcc not on PATH" >&2; exit 1; }
GCCVER="$("${BGCC}" -dumpversion 2>/dev/null || echo unknown)"
[ "${GCCVER}" = "${GCC_VERSION}" ] || {
  echo "ocaml infra: gcc -dumpversion = '${GCCVER}', expected '${GCC_VERSION}' (gcc-15.2.0-glibc, B5)." >&2
  echo "             Refusing to build: an unexpected host compiler makes this edge meaningless." >&2
  exit 1; }
for t in as ld ar ranlib strip readelf make sed grep; do
  command -v "$t" >/dev/null 2>&1 || { echo "ocaml infra: '$t' not on PATH" >&2; exit 1; }
done
# Name these failures now rather than as a mystery "stdio.h: No such file" minutes into the build.
[ -e "${SR}/lib/libc.so" ]     || { echo "ocaml infra: B4 sysroot missing at ${SR} (libc.so)" >&2; exit 1; }
[ -f "${SR}/lib/crt1.o" ]      || { echo "ocaml infra: B4 startfiles missing (${SR}/lib/crt1.o)" >&2; exit 1; }
[ -e "${LOADER}" ]             || { echo "ocaml infra: B4 loader missing at ${LOADER}" >&2; exit 1; }
[ -f "${SR}/include/stdio.h" ] || { echo "ocaml infra: B4 headers missing at ${SR}/include" >&2; exit 1; }
[ -d "${SR}/include/linux" ]   || { echo "ocaml infra: kernel UAPI not co-located in ${SR}/include" >&2; exit 1; }

# --- B4 libc.so linker-script fixup --------------------------------------------------------
# The sealed B4 versioned libc.so is a linker SCRIPT that baked /build/output/... staging paths.
# Regenerate a corrected copy and put it FIRST on the library path.  Shape verbatim from
# gcc-15.2.0-glibc/build.sh:53-58 (whose own gate "bit exactly this") and packages/mrustc.
# NOTE: unlike mrustc this copy lives under $OUTPUT_DIR, not $BUILDROOT — ocamlopt BAKES its -L
# paths and must still resolve them at runtime, so the fixup has to ship with the package.
FIXLIB="${OUTPUT_DIR}/usr/lib/ocaml-bedrock-link"; mkdir -p "${FIXLIB}"
sed -E "s@[^ ()]*/(libc\.so\.6|libc_nonshared\.a|${LOADER_SO})@${SR}/lib/\1@g" \
  "${SR}/lib/libc.so" > "${FIXLIB}/libc.so"
if grep -q '/build/output' "${FIXLIB}/libc.so"; then
  echo "ocaml infra: libc.so linker-script fixup failed (staging paths survive)" >&2; exit 1
fi
RTLIB=/usr/lib/ocaml-bedrock-link       # the same dir as seen from a consumer rootfs

GIX="$("${BGCC}" -print-file-name=include)"
[ -f "${GIX}/stdint.h" ] || { echo "ocaml infra: gcc internal headers not at '${GIX}'" >&2; exit 1; }

# -nostdinc + an explicit chain: B5's gcc dropped --with-native-system-header-dir, so it looks
# for libc headers at the default /usr/include and will NOT find B4's.  We also deliberately keep
# /usr/include OFF the path — it is written by multiple deps through an unordered, first-writer-
# wins hardlink pass, so relying on its contents is a per-run coin flip.
BEDROCK_CPPFLAGS="-nostdinc -isystem ${GIX} -isystem ${SR}/include"
# --dynamic-linker: there is no /lib64 symlink in the sandbox, so without it the produced
# binaries cannot be EXECUTED — and both the fixpoint gate and the pkg tests execute them.
# -rpath so they run with no LD_LIBRARY_PATH, here and downstream.
BEDROCK_LDFLAGS="-L${RTLIB} -B${SR}/lib -L${SR}/lib -L/usr/lib -Wl,--dynamic-linker=${LOADER} -Wl,-rpath,${SR}/lib:${RTLIB}:/usr/lib -Wl,--build-id=none"

export CFLAGS="$MARCH -O2 -pipe -gno-record-gcc-switches -ffile-prefix-map=$(pwd)=/builddir ${BEDROCK_CPPFLAGS}"
export CPPFLAGS="${BEDROCK_CPPFLAGS}"
export LDFLAGS="-Wl,--build-id=none ${BEDROCK_LDFLAGS}"
export ARFLAGS="Drc"
# OCaml natively implements the reproducible-builds BUILD_PATH_PREFIX_MAP spec —
# it rewrites embedded build paths in .cmi/.cmt/.a and debug info. Honored by
# both ./configure and make.
export BUILD_PATH_PREFIX_MAP="/builddir=$(pwd)"

# ★ STASH UPSTREAM'S COMMITTED BLOBS *BEFORE* ANYTHING RUNS.
# Required for the fixpoint gate below to mean what its comment claims. `make bootstrap` is
# `bootstrap: coreboot` (Makefile:862), and coreboot's FIRST step is promote-cross ->
# promote-common -> `$(PROMOTE) ocamlc boot/ocamlc` (Makefile:770,762-763) — it OVERWRITES the
# shipped blob before any comparison happens. Capturing it here is the only way to compare
# against what upstream actually shipped rather than against our own previous generation.
UPSTREAM_BOOT="${BUILDROOT:-/tmp}/upstream-boot"; mkdir -p "${UPSTREAM_BOOT}"
cp boot/ocamlc "${UPSTREAM_BOOT}/ocamlc"
cp boot/ocamllex "${UPSTREAM_BOOT}/ocamllex" 2>/dev/null || true
[ -s "${UPSTREAM_BOOT}/ocamlc" ] || { echo "ocaml infra: failed to stash upstream boot/ocamlc" >&2; exit 1; }

# The release tarball ships a pre-generated ./configure (no autogen). Disable
# zstd (optional .cmi compression) to avoid the extra system dep.
./configure --prefix=/usr --without-zstd

# world.opt = bytecode world + native (ocamlopt) compilers, bootstrapped from
# the tarball's boot/ocamlc — no host OCaml, no network.
make -j"$(nproc)" world.opt
make install DESTDIR="$OUTPUT_DIR"

# ============================================================================================
# ★ BEDROCK-ROOTING GATE — prove the swap actually took.
#
# The failure this exists to catch: ./configure quietly ignoring our CFLAGS/LDFLAGS and
# configuring against an ambient toolchain. That produces a perfectly GREEN build which still
# roots OCaml in the self-hosting gcc clique — i.e. the exact claim this change is making would
# be false, with nothing to show it. A dep swap that cannot be observed in the output is not a
# dep swap. So assert it on the ARTIFACT, three independent ways.
# ============================================================================================
OCAMLC_BIN="${OUTPUT_DIR}/usr/bin/ocamlc"
[ -x "${OCAMLC_BIN}" ] || { echo "OCAML-BEDROCK-GATE: FAIL — no ocamlc at ${OCAMLC_BIN}" >&2; exit 1; }

# (1) The binary we just built must itself run on the B4 loader, not the ambient one.
INTERP="$(readelf -l "${OCAMLC_BIN}" 2>/dev/null | sed -n 's/.*interpreter: \(.*\)\]/\1/p')"
case "${INTERP}" in
  "${LOADER}") echo "OCAML-BEDROCK-GATE 1/3: PASS interp=${INTERP}" >&2 ;;
  *) echo "OCAML-BEDROCK-GATE 1/3: FAIL — ocamlc .interp='${INTERP}', expected '${LOADER}'." >&2
     echo "  The build did NOT link against the B4 sysroot; it is not seed-rooted." >&2
     exit 1 ;;
esac

# (2) The BAKED config is what ocamlopt will re-invoke at runtime. If the sysroot is absent
#     here, every native binary a user later links silently uses some other libc.
OCAML_CFG="$("${OCAMLC_BIN}" -config 2>/dev/null || true)"
echo "${OCAML_CFG}" | grep -q -- "${SR}" || {
  echo "OCAML-BEDROCK-GATE 2/3: FAIL — '${SR}' absent from \`ocamlc -config\`." >&2
  echo "  configure did not persist the bedrock sysroot; ocamlopt would link against the wrong libc." >&2
  echo "${OCAML_CFG}" | grep -E 'c_compiler|ocamlopt_c|native_c_(compiler|libraries)|bytecomp_c' >&2 || true
  exit 1; }
echo "OCAML-BEDROCK-GATE 2/3: PASS (bedrock sysroot persisted into ocamlc -config)" >&2

# (3) Nothing baked may point into the build tree — those paths vanish at runtime. This is the
#     concrete trap that made the $OUTPUT_DIR (not $BUILDROOT) choice for FIXLIB necessary.
if echo "${OCAML_CFG}" | grep -qE '/build/(output|root)|/builddir'; then
  echo "OCAML-BEDROCK-GATE 3/3: FAIL — build-tree paths baked into ocamlc -config:" >&2
  echo "${OCAML_CFG}" | grep -E '/build/(output|root)|/builddir' >&2
  exit 1
fi
echo "OCAML-BEDROCK-GATE 3/3: PASS (no build-tree paths baked into the installed compiler)" >&2
echo "OCAML-BEDROCK-GATE: ocaml 5.5.0 is rooted at B5 gcc-15.2.0-glibc (hex0 -> ... -> R12 -> B5)" >&2

# ============================================================================================
# ★ BOOTSTRAP FIXPOINT GATE (issue #48).
#
# THE PROBLEM THIS ADDRESSES: OCaml does not build from source the way the rest of the catalogue
# does. `make world` runs boot/ocamlc — a 3.65 MB COMMITTED BYTECODE IMAGE of the compiler that
# ships inside the release tarball — and that blob compiles the stdlib and then the compiler
# itself. So "we build OCaml from source" quietly means "we trust a binary blob we did not build."
# It is the same trust-by-fiat class as the go.dev bindist that #19 retired.
#
# WHAT THIS GATE PROVES: `make bootstrap` rebuilds boot/ocamlc USING the compiler we just built,
# then compares the regenerated blob against the shipped one (tools/cmpbyt / the Makefile's own
# compare step). If they agree, the shipped blob is a FIXED POINT of the source we shipped —
# i.e. the blob is not smuggling in behaviour absent from the source tree.
#
# WHAT IT DOES *NOT* PROVE — state this plainly, because the distinction is the whole point:
# a fixpoint check does NOT defeat a Thompson attack. A blob carrying a self-reproducing backdoor
# regenerates itself and passes this gate perfectly. Only a ladder rooted outside OCaml
# (camlboot -> 4.07 -> ... -> 5.x, tracked in #48) can retire the blob. This gate raises the cost
# of a mismatch to "impossible to ignore"; it does not close the hole.
#
# Non-fatal for now (|| true on the compare): this lands as a MEASUREMENT first so we learn whether
# upstream's blob is even a fixed point for our build flags, before it can wedge the catalogue.
# Promote to fail-shut once it has been green twice.
# ============================================================================================
echo "OCAML-FIXPOINT: regenerating boot/ocamlc with the compiler we just built" >&2
if make bootstrap >/tmp/ocaml-bootstrap.log 2>&1; then
  echo "OCAML-FIXPOINT: PASS — self-consistent fixed point reached (our gen N == our gen N+1)" >&2
else
  echo "OCAML-FIXPOINT: MISMATCH or build error (non-fatal today; see tail) —" >&2
  tail -20 /tmp/ocaml-bootstrap.log >&2 || true
fi

# ── THE COMPARISON THAT WAS MISSING ─────────────────────────────────────────────────────────
# What `make bootstrap` alone proves is NARROWER than it looks, and the previous version of this
# block mis-stated it. `bootstrap: coreboot` (Makefile:862) begins with promote-cross ->
# promote-common -> `$(PROMOTE) ocamlc boot/ocamlc` (Makefile:770,762-763): the shipped blob is
# OVERWRITTEN FIRST. The `compare` step (Makefile:749) therefore checks OUR generation N against
# OUR generation N+1 — self-consistency — and says nothing whatever about the blob upstream
# actually shipped. A backdoored blob that reproduces itself passes it trivially.
#
# Comparing against the stashed upstream blob is a strictly stronger statement: it says the bytes
# upstream shipped are the bytes this source tree produces. Report-only, because a mismatch is
# EXPECTED and is not a defect: upstream's blob has its own ./configure substitutions baked in
# (prefix, target triplet, probed gcc flags land in utils/config.mlp), so byte-identity requires
# reproducing upstream's build environment, not just its source.
if [ -s "${UPSTREAM_BOOT}/ocamlc" ] && [ -f boot/ocamlc ]; then
  if cmp -s "${UPSTREAM_BOOT}/ocamlc" boot/ocamlc; then
    echo "OCAML-UPSTREAM-CMP: IDENTICAL — our regenerated boot/ocamlc matches upstream's shipped blob byte for byte" >&2
  else
    echo "OCAML-UPSTREAM-CMP: DIFFERS — upstream $(wc -c < "${UPSTREAM_BOOT}/ocamlc")B vs ours $(wc -c < boot/ocamlc)B" >&2
    echo "  Expected today (configure substitutions are baked into the blob). Recorded so that the" >&2
    echo "  #48 end-state can say precisely which claim we hold: 'seed-rooted' vs 'byte-identical" >&2
    echo "  to upstream'. These are different claims and only this line distinguishes them." >&2
  fi
else
  echo "OCAML-UPSTREAM-CMP: SKIPPED — no stashed upstream blob to compare against" >&2
fi
echo "OCAML-FIXPOINT: NOTE neither check defeats Thompson; only the #48 ladder retires the blob" >&2


# ocamldebug mixes C + bytecode; exclude it from any blanket debug strip.
find "${OUTPUT_DIR}/usr/bin" -type f -executable ! -name 'ocamldebug' \
  | xargs strip --strip-unneeded 2>/dev/null || true
