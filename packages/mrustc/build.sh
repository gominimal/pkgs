#!/bin/sh
# ============================================================================================
# build.sh — mrustc 0.12.0, built by our seed-rooted g++ (issue #17, THE JOINT).
#
# Reads as five phases:
#   P0  preconditions  — every anchor asserted by NAME before anything is built
#   P1  sysroot harness — B5's own proven flag set + the B4 libc.so linker-script fixup
#   P2  determinism    — kill Makefile:190's wall-clock/git shell-outs, then PROVE it
#   P3  build+install
#   P4  gates          — FUNCTIONAL (compile AND run), from ${OUTPUT_DIR}, after install
#
# Every assertion is fail-shut with a named message, because this rung has never been built in
# CS and the first failure should be diagnosable from one log read rather than a bisect.
# ============================================================================================
set -ex

VERSION="${MINIMAL_ARG_VERSION:-0.12.0}"
COMMIT="${MINIMAL_ARG_COMMIT:-2d14b09a7e75166bec4413f48f61e3b3cd4de8ca}"
TARBALL="mrustc-${VERSION}.tar"
SRC="mrustc-${VERSION}"
BUILDROOT="$(pwd)"

# The tarball sha we pinned in build.ncl, re-asserted here so a mirror swap cannot slip past the
# fetcher's check silently.  Defence in depth, not a substitute for the Source sha256.
SRC_SHA=1ad6521c90e47754c5e13bd9abd183f4cd953eb9faa8a25e7b104b6ffe701512

# mrustc runtime knobs.  RUSTC_VERSION/OUTDIR_SUF are NOT needed at this scope (no libstd, no
# rustc source) but MRUSTC_TARGET_VER is: src/main.cpp:969 reads it and src/main.cpp:995 only
# WARNS when it is unset, silently falling back to 1.29 mode.  That is a fail-open, so we pin it
# and gate on 1.90 behaviour (samples/no_core-1_90.rs's 4-arg lang_start is 1.74+-only shape).
TARGET_VER=1.90
TRIPLE=x86_64-unknown-linux-gnu
CCTRIPLE=x86_64-linux-gnu          # Target_GetCurSpec().m_backend_c.m_c_compiler (src/trans/target.cpp:440)

GCC_VERSION=15.2.0
SR=/usr/lib/glibc-bedrock-2.42     # B4 versioned sysroot: headers + crt + libs + co-located UAPI
LOADER="${SR}/lib/ld-linux-x86-64.so.2"

# ============================================================================================
# P0 — PRECONDITIONS.  Assert the ANCHOR, not just "a compiler".
# ============================================================================================
BGCC="$(command -v gcc || true)"
BGXX="$(command -v g++ || command -v ${CCTRIPLE}-g++ || true)"
[ -n "${BGCC}" ] || { echo "mrustc infra: B5 gcc not on PATH" >&2; exit 1; }
[ -n "${BGXX}" ] || { echo "mrustc infra: B5 g++ (the C++ HOST compiler — the whole point) not on PATH" >&2; exit 1; }
for t in as ld ar ranlib objcopy strip make sed grep tar sha256sum; do
  command -v "$t" >/dev/null 2>&1 || { echo "mrustc infra: '$t' not on PATH" >&2; exit 1; }
done

# The joint is only the joint if the compiler really is the seed-rooted gcc-15.2.0.  A wrong or
# ambient g++ here would produce a green build that proves nothing, so bind it explicitly.
GXXVER="$("${BGXX}" -dumpversion 2>/dev/null || echo unknown)"
[ "${GXXVER}" = "${GCC_VERSION}" ] || {
  echo "mrustc infra: g++ -dumpversion = '${GXXVER}', expected '${GCC_VERSION}' (gcc-15.2.0-glibc, B5)." >&2
  echo "              Refusing to build: an unexpected host compiler makes this edge meaningless." >&2
  exit 1; }

# B4 sysroot (B5's gcc dropped --with-native-system-header-dir, so it looks for libc headers at
# the default /usr/include and will NOT find B4's without the explicit -isystem chain below).
[ -e "${SR}/lib/libc.so" ]        || { echo "mrustc infra: B4 sysroot missing at ${SR} (libc.so)" >&2; exit 1; }
[ -f "${SR}/lib/crt1.o" ]         || { echo "mrustc infra: B4 startfiles missing at ${SR}/lib (crt1.o)" >&2; exit 1; }
[ -f "${SR}/lib/Scrt1.o" ]        || { echo "mrustc infra: B4 PIE startfiles missing at ${SR}/lib (Scrt1.o)" >&2; exit 1; }
[ -e "${LOADER}" ]                || { echo "mrustc infra: B4 loader missing at ${LOADER}" >&2; exit 1; }
[ -f "${SR}/include/stdio.h" ]    || { echo "mrustc infra: B4 headers missing at ${SR}/include" >&2; exit 1; }
# B4 co-locates the kernel UAPI INTO the sysroot (glibc-bedrock-2.42/build.sh:163) precisely so
# consumers never have to reach into the coin-flip /usr.  If that ever stops being true we want a
# named failure here, not a mystery "linux/limits.h: No such file" three minutes into the build.
[ -d "${SR}/include/linux" ]      || { echo "mrustc infra: kernel UAPI not co-located in ${SR}/include (expected linux/)" >&2; exit 1; }

# B5 C++ runtime + headers
CB="/usr/include/c++/${GCC_VERSION}"
[ -d "${CB}" ]                    || { echo "mrustc infra: B5 C++ headers missing at ${CB}" >&2; exit 1; }
[ -f "${CB}/${CCTRIPLE}/bits/c++config.h" ] || { echo "mrustc infra: B5 target C++ config missing at ${CB}/${CCTRIPLE}" >&2; exit 1; }
ls /usr/lib/libstdc++.so.6* >/dev/null 2>&1 || { echo "mrustc infra: B5 libstdc++.so.6 missing at /usr/lib" >&2; exit 1; }
# mrustc's emitted C is linked with `-l atomic` unconditionally (BACKEND_C_OPTS_GNU,
# src/trans/target.cpp:424).  R12 disables libatomic; B5 ships it.  This assert is exactly why
# the anchor has to be B5 and not R12.
ls /usr/lib/libatomic.so* >/dev/null 2>&1 || { echo "mrustc infra: libatomic missing — mrustc codegen links '-l atomic' unconditionally" >&2; exit 1; }

# zlib (Makefile:45 LIBS := -lz)
[ -f /usr/include/zlib.h ]        || { echo "mrustc infra: zlib.h missing at /usr/include" >&2; exit 1; }
ls /usr/lib/libz.so* >/dev/null 2>&1 || { echo "mrustc infra: libz.so missing at /usr/lib" >&2; exit 1; }

# ============================================================================================
# P0b — OFFLINE, PROVEN.  minicargo.mk:224's curl is unreachable from the `all` and
# `tools/minicargo` targets, but "unreachable by my reading of a Makefile" is not evidence.
# Put loud tripwires on PATH and assert afterwards that none of them fired.
# ============================================================================================
STUBS="${BUILDROOT}/stubs"; mkdir -p "${STUBS}"
for t in curl wget git; do
  cat > "${STUBS}/${t}" <<EOF
#!/bin/sh
echo "\$0 \$*" >> "${BUILDROOT}/NETWORK-TRIPWIRE"
echo "mrustc: FATAL — the build invoked '${t}', which must never happen offline" >&2
exit 1
EOF
  chmod 0755 "${STUBS}/${t}"
done
PATH="${STUBS}:${PATH}"; export PATH

# ============================================================================================
# P1 — UNPACK + SYSROOT HARNESS
# ============================================================================================
have_sha="$(sha256sum < "${TARBALL}" | cut -d' ' -f1)"
[ "${have_sha}" = "${SRC_SHA}" ] || {
  echo "mrustc: FATAL tarball sha ${have_sha} != pinned ${SRC_SHA}" >&2; exit 1; }

tar --no-same-owner -xf "${TARBALL}"
[ -d "${SRC}" ] || { echo "mrustc: FATAL tarball did not unpack to ${SRC}/" >&2; exit 1; }

# Bind the source identity to the pinned COMMIT, not just to a filename.  0.12.0's version
# constants live in src/version.cpp:11-13.
for f in Makefile minicargo.mk src/version.cpp samples/no_core-1_90.rs tools/minicargo/Makefile tools/common/Makefile; do
  [ -f "${SRC}/${f}" ] || { echo "mrustc: FATAL expected source file missing: ${f}" >&2; exit 1; }
done
grep -q '^#define VERSION_MAJOR   0$' "${SRC}/src/version.cpp" || { echo "mrustc: FATAL VERSION_MAJOR != 0" >&2; exit 1; }
grep -q '^#define VERSION_MINOR   12$' "${SRC}/src/version.cpp" || { echo "mrustc: FATAL VERSION_MINOR != 12 (not the 0.12 tree)" >&2; exit 1; }

# --- B4 libc.so linker-script fixup -------------------------------------------------------
# The sealed B4 versioned libc.so is a linker SCRIPT that baked /build/output/... staging paths.
# Regenerate a corrected copy and put it FIRST on the library path.  Verbatim shape from
# gcc-15.2.0-glibc/build.sh:53-58, whose comment records that its own gate "bit exactly this".
FIXLIB="${BUILDROOT}/glibc-fixlib"; mkdir -p "${FIXLIB}"
sed -E "s@[^ ()]*/(libc\.so\.6|libc_nonshared\.a|ld-linux-x86-64\.so\.2)@${SR}/lib/\1@g" \
  "${SR}/lib/libc.so" > "${FIXLIB}/libc.so"
if grep -q '/build/output' "${FIXLIB}/libc.so"; then
  echo "mrustc infra: libc.so linker-script fixup failed (staging paths survive)" >&2; exit 1
fi

GIX="$("${BGXX}" -print-file-name=include)"
[ -f "${GIX}/stdint.h" ] || { echo "mrustc infra: gcc internal headers not at '${GIX}'" >&2; exit 1; }

# Private zlib header dir.  We do NOT put /usr/include on the include path: that directory is
# written by multiple deps through an UNORDERED HashSet with first-writer-wins hardlinks
# (sandbox2 config.rs:106 + common lib.rs:206), so relying on its contents is a per-run coin
# flip.  Single-writer discipline: copy the two headers we actually need.
ZINC="${BUILDROOT}/zinc"; mkdir -p "${ZINC}"
cp /usr/include/zlib.h /usr/include/zconf.h "${ZINC}/"

CXXINC="-nostdinc -nostdinc++ -isystem ${CB} -isystem ${CB}/${CCTRIPLE} -isystem ${CB}/backward -isystem ${GIX} -isystem ${ZINC} -isystem ${SR}/include"
CINC="-nostdinc -isystem ${GIX} -isystem ${SR}/include"
# -L${FIXLIB} FIRST (see above).  --dynamic-linker: there is no /lib64 symlink in the sandbox, so
# without it the produced binaries cannot be executed — and the gate must EXECUTE.  -rpath so the
# gate binaries and bin/mrustc itself run with no LD_LIBRARY_PATH, here and downstream.
# --build-id=none for byte-seal parity with binutils-2.46-glibc and B5.
LNK="-L${FIXLIB} -B${SR}/lib -L${SR}/lib -L/usr/lib -Wl,--dynamic-linker=${LOADER} -Wl,-rpath,${SR}/lib:/usr/lib -Wl,--build-id=none"

# --- compiler wrappers --------------------------------------------------------------------
# mrustc bakes its own CC argv (src/trans/codegen_c.cpp:1277-1392) and there is no hook to inject
# -isystem/-L into it, so the ONLY way to point it at a pinned sysroot is to make $CC a wrapper.
# This is the bedrock ladder's own pattern (stage0-gcc-10.4.0/build.sh:70-76).
WRAP="${BUILDROOT}/wrap"; mkdir -p "${WRAP}"

cat > "${WRAP}/bedrock-c++" <<EOF
#!/bin/sh
# g++ pinned to the B5 C++ headers + B4 sysroot.  Compile-only invocations get includes only.
case " \$* " in
  *" -c "*) exec "${BGXX}" ${CXXINC} "\$@" ;;
esac
exec "${BGXX}" ${CXXINC} "\$@" ${LNK}
EOF

# The CC mrustc shells out to at codegen time.  It also LOGS every invocation: the gate below
# asserts the log is non-empty, which is the machine-checkable statement that the Rust program
# was really compiled through OUR hex0-rooted gcc and not through something ambient.
cat > "${WRAP}/bedrock-cc" <<EOF
#!/bin/sh
echo "cc \$*" >> "${BUILDROOT}/ccwrap.log"
case " \$* " in
  *" -c "*) exec "${BGCC}" ${CINC} "\$@" ;;
esac
exec "${BGCC}" ${CINC} "\$@" ${LNK}
EOF
chmod 0755 "${WRAP}/bedrock-c++" "${WRAP}/bedrock-cc"

# ============================================================================================
# P2 — DETERMINISM PATCH (Makefile:190)
# ============================================================================================
cd "${SRC}"

# Five `$(shell ...)` calls, each occurring exactly once in the file (asserted below by the
# residual check).  Plain BRE: none of the needles contain . * [ ] \ ^, and `$` is literal when
# not final, so these are safe as literal patterns.
sed -i \
 -e 's@$(shell git show --pretty=%H -s --no-show-signature)@$(MRUSTC_GIT_FULLHASH)@' \
 -e 's@$(shell git symbolic-ref -q --short HEAD || git describe --tags --exact-match)@$(MRUSTC_GIT_BRANCH)@' \
 -e 's@$(shell git show -s --pretty=%h --no-show-signature)@$(MRUSTC_GIT_SHORTHASH)@' \
 -e 's@$(shell env LC_TIME=C date -u +"%a, %e %b %Y %T +0000")@$(MRUSTC_BUILDTIME)@' \
 -e 's@$(shell git diff-index --quiet HEAD; echo $$?)@$(MRUSTC_GIT_ISDIRTY)@' \
 Makefile

# Fail-shut if upstream ever reshapes that line: better a named failure than a silently
# re-introduced wall-clock stamp that only shows up as a repro-check diff weeks later.
if grep -qE 'shell git|shell env|date -u' Makefile; then
  echo "mrustc: FATAL residual wall-clock/git shell-out in Makefile after the determinism patch:" >&2
  grep -nE 'shell git|shell env|date -u' Makefile >&2
  exit 1
fi
for v in MRUSTC_GIT_FULLHASH MRUSTC_GIT_BRANCH MRUSTC_GIT_SHORTHASH MRUSTC_BUILDTIME MRUSTC_GIT_ISDIRTY; do
  grep -q "\$(${v})" Makefile || { echo "mrustc: FATAL determinism patch did not install \$(${v})" >&2; exit 1; }
done

# The sandbox exports SOURCE_DATE_EPOCH=0 (sandbox2 lib.rs:331-336) but plain `date` does not
# read it, which is exactly why the patch above is mandatory rather than cosmetic.  Reproduce
# upstream's format string against the epoch so the embedded value is principled, not magic.
MRUSTC_BUILDTIME="$(LC_ALL=C date -u -d "@${SOURCE_DATE_EPOCH:-0}" +'%a, %e %b %Y %T +0000')"
MRUSTC_GIT_FULLHASH="${COMMIT}"
MRUSTC_GIT_SHORTHASH="$(echo "${COMMIT}" | cut -c1-7)"
MRUSTC_GIT_BRANCH="v${VERSION}"
# MUST be 0 and MUST be non-empty: src/version.cpp:26 is
#   bool gbVersion_GitDirty = VERSION_GIT_ISDIRTY;
# an UNQUOTED macro, so an empty value compiles to `bool x = ;` — a hard syntax error.  Upstream
# is accidentally safe here because `git diff-index ...; echo $?` always prints something even
# when git is absent; parameterising the line deletes that accident.
MRUSTC_GIT_ISDIRTY=0
export MRUSTC_BUILDTIME MRUSTC_GIT_FULLHASH MRUSTC_GIT_SHORTHASH MRUSTC_GIT_BRANCH MRUSTC_GIT_ISDIRTY

# ============================================================================================
# P3 — BUILD + INSTALL
# ============================================================================================
JOBS="$(nproc 2>/dev/null || echo 4)"

# MRUSTC_CCACHE must stay UNSET (src/trans/codegen_c.cpp:1491) — build-1.90.0.sh:5 opts into it
# when ccache is on PATH, which would be a hermeticity hole.  Unset defensively.
unset MRUSTC_CCACHE CFLAGS CXXFLAGS LDFLAGS RUSTFLAGS 2>/dev/null || true

# Command-line variable overrides propagate to the `$(MAKE) -C tools/common` sub-make via
# MAKEFLAGS, so common_lib.a is built with the same wrapper.
MK="CXX=${WRAP}/bedrock-c++ AR=ar OBJCOPY=objcopy STRIP=strip"
make -j"${JOBS}" ${MK} all
make -j"${JOBS}" ${MK} -C tools/minicargo

[ -x bin/mrustc ]    || { echo "mrustc: FATAL bin/mrustc not produced" >&2; exit 1; }
[ -x bin/minicargo ] || { echo "mrustc: FATAL bin/minicargo not produced" >&2; exit 1; }
for b in bin/mrustc bin/minicargo; do
  magic="$(head -c 4 "$b" | od -An -tx1 | tr -d ' \n')"
  [ "${magic}" = "7f454c46" ] || { echo "mrustc: FATAL ${b} is not an ELF (magic=${magic})" >&2; exit 1; }
done

# --- offline tripwire ---------------------------------------------------------------------
if [ -e "${BUILDROOT}/NETWORK-TRIPWIRE" ]; then
  echo "mrustc: FATAL the build attempted a network fetch:" >&2
  cat "${BUILDROOT}/NETWORK-TRIPWIRE" >&2
  exit 1
fi
echo "MRUSTC-OFFLINE: PASS (no curl/wget/git invocation during the build)" >&2

# --- determinism proof --------------------------------------------------------------------
# Assert the pinned buildtime string is what actually landed in .rodata (it survives `strip`;
# Makefile:176-180 strips symbols, not .rodata), then rebuild version.o at a strictly later
# wall-clock instant and assert bin/mrustc is byte-identical.  Unpatched, this check FAILS.
grep -a -F -q "${MRUSTC_BUILDTIME}" bin/mrustc || {
  echo "mrustc: FATAL pinned VERSION_BUILDTIME '${MRUSTC_BUILDTIME}' not found in bin/mrustc" >&2; exit 1; }

sha_1="$(sha256sum < bin/mrustc | cut -d' ' -f1)"
touch src/version.cpp
make -j"${JOBS}" ${MK} all
sha_2="$(sha256sum < bin/mrustc | cut -d' ' -f1)"
if [ "${sha_1}" = "${sha_2}" ]; then
  echo "MRUSTC-DETERMINISM: PASS (version.o rebuilt later in wall-clock time; bin/mrustc byte-identical ${sha_1})" >&2
else
  echo "MRUSTC-DETERMINISM: FAIL ${sha_1} != ${sha_2} — a wall-clock/entropy source survives the Makefile:190 patch" >&2
  exit 1
fi

# --- install ------------------------------------------------------------------------------
mkdir -p "${OUTPUT_DIR}/usr/bin" "${OUTPUT_DIR}/usr/share/mrustc/patches"
cp bin/mrustc bin/minicargo "${OUTPUT_DIR}/usr/bin/"
chmod 0755 "${OUTPUT_DIR}/usr/bin/mrustc" "${OUTPUT_DIR}/usr/bin/minicargo"

# Land the strand (see build.ncl).  Not applied at this scope — there is no rustc source here —
# but shipped so its bytes are attested and the downstream rustc rung reads it from the rootfs.
cp "${BUILDROOT}/archive-zerolen-skip.sh" "${OUTPUT_DIR}/usr/share/mrustc/patches/"
chmod 0755 "${OUTPUT_DIR}/usr/share/mrustc/patches/archive-zerolen-skip.sh"

# Self-describing provenance.  Fixed constants only — nothing here varies between runs.
cat > "${OUTPUT_DIR}/usr/share/mrustc/BUILDINFO" <<EOF
mrustc-version: ${VERSION}
mrustc-commit: ${COMMIT}
source-tarball-sha256: ${SRC_SHA}
host-cxx: gcc-15.2.0-glibc (B5), g++ ${GXXVER}
host-sysroot: ${SR} (glibc-bedrock-2.42, B4)
host-binutils: binutils-2.46-glibc
version-buildtime: ${MRUSTC_BUILDTIME}
mrustc-target-ver: ${TARGET_VER}
scope: mrustc + minicargo only (no libstd, no rustc, no LLVM)
seal-status: see mrustc.answers
EOF

# ============================================================================================
# P4 — FUNCTIONAL GATES.  Run the INSTALLED binaries from ${OUTPUT_DIR}, never the build tree.
# A --version gate is banned here for the reason the project already paid for once: a
# --version-only gate shipped a broken `as` for days.  These gates make mrustc lower Rust to C,
# shell out to our gcc, link, and then EXECUTE the result.
# ============================================================================================
MR="${OUTPUT_DIR}/usr/bin/mrustc"
MC="${OUTPUT_DIR}/usr/bin/minicargo"
GATE="${BUILDROOT}/gate"; mkdir -p "${GATE}"

export MRUSTC_TARGET_VER="${TARGET_VER}"
# CC_<triple> takes priority over CC (codegen_c.cpp:1284-1292); set both so there is no path by
# which mrustc reaches an ambient compiler.
export CC_x86_64_linux_gnu="${WRAP}/bedrock-cc"
export CC="${WRAP}/bedrock-cc"

# --- GATE 1: mrustc compiles a self-contained #![no_core] program, gcc links it, it RUNS -----
# NOT `make test`: minicargo.mk:224 curls rustc-1.29.0-src.tar.gz (that was the 3rd CS failure,
# caught by P0b's tripwire), and the "fix" -- pre-placing a 106MB tarball -- would convert this
# rung into the full libstd build that build.ncl:20-24 explicitly says it is NOT.
# NOT samples/no_core-1_90.rs: build-1.90.0.sh:25 compiles that with the mrustc-BUILT rustc,
# which belongs to a later rung.
#
# gate.rs escapes the historical wall by DECLARING #[lang="RangeFull"] itself, so
# static_borrow_constants.cpp:55-66's lookup succeeds and its core-requiring fallback (which
# BUGs at src/hir/hir.cpp:343) is never entered.  This falsifies the earlier note in this file
# claiming bare mrustc cannot compile ANY standalone program -- it can, given that lang item.
# Verified CAUSALLY: delete that one line and the wall returns verbatim.
#
# MEASURED OFFLINE, twice independently, at the pinned commit 2d14b09, on amd64 AND arm64, with
# networking proven dead by raw-IP TCP probes AND the P0b abort-stubs on PATH (never fired).
# Non-vacuity is causal too: neutering the four `!=` checks yields 49, not 42.
cp "${BUILDROOT}/gate.rs" "${GATE}/gate.rs"
set +e
( cd "${GATE}" && "${MR}" gate.rs -o "${GATE}/gate" --cfg debug_assertions -g -O ) \
  >"${GATE}/g1-compile.log" 2>&1
g1c=$?
set -e
if [ ${g1c} -ne 0 ]; then
  echo "MRUSTC-GATE-1: FAIL (mrustc could not compile the gate program, rc=${g1c}); tail:" >&2
  tail -40 "${GATE}/g1-compile.log" >&2 || true
  grep -q '__rdl_' "${GATE}/g1-compile.log" && \
    echo "HINT: undefined __rdl_* is an ld --gc-sections problem, NOT a missing libcore." >&2
  exit 1
fi
[ -x "${GATE}/gate" ] || { echo "MRUSTC-GATE-1: FAIL (rc=0 but no ${GATE}/gate produced)" >&2; exit 1; }
set +e; "${GATE}/gate"; grc=$?; set -e
case ${grc} in
  42)  : ;;
  101) echo "MRUSTC-GATE-1: FAIL — trait/generic/mul path (total(&Pair{3,4}) != 14)" >&2; exit 1 ;;
  102) echo "MRUSTC-GATE-1: FAIL — loop/add path (accum(5) != 10)" >&2; exit 1 ;;
  103) echo "MRUSTC-GATE-1: FAIL — enum/match path (pick(Sel::B) != 2)" >&2; exit 1 ;;
  104) echo "MRUSTC-GATE-1: FAIL — raw-pointer/sub path (via_ptr(20) != 16)" >&2; exit 1 ;;
  *)   echo "MRUSTC-GATE-1: FAIL — gate binary exited ${grc}, expected 42" >&2; exit 1 ;;
esac
echo "MRUSTC-GATE-1: PASS (mrustc lowered a no_core Rust program to C with NO -L and no network; the configured \$CC linked it; the binary RAN and returned the computed 42)" >&2

# Re-assert offline HERE: build.sh's earlier tripwire check runs at the end of P3, before any
# gate, so a fetch attempted during P4 would otherwise go unnoticed.
if [ -e "${BUILDROOT}/NETWORK-TRIPWIRE" ]; then
  echo "mrustc: FATAL a network fetch was attempted (P4/gate phase):" >&2
  cat "${BUILDROOT}/NETWORK-TRIPWIRE" >&2; exit 1
fi


# --- GATE 3: the joint itself, machine-checked --------------------------------------------
# Assert mrustc really shelled out to OUR wrapper (and therefore to the seed-rooted gcc) for the
# codegen backend.  Without this, GATE 1's hello-world could in principle have been linked by
# some other compiler and the provenance claim would be unearned.
# (GATE 1's gate.rs compile is what drives codegen now — mrustc lowers it to C and invokes $CC
# to build/link it, which is exported to the wrapper just above.)
if [ -s "${BUILDROOT}/ccwrap.log" ]; then
  ccn="$(wc -l < "${BUILDROOT}/ccwrap.log" | tr -d ' ')"
  echo "MRUSTC-GATE-3: PASS (mrustc invoked the pinned B5 gcc ${ccn}x for C codegen)" >&2
else
  echo "MRUSTC-GATE-3: FAIL (mrustc never invoked \$CC — the gate binaries did not come from our gcc)" >&2
  exit 1
fi

# --- GATE 4: minicargo is a working binary, not just a file -------------------------------
# minicargo takes no meaningful no-arg action, so gate it on the fact that it loads and runs its
# argument parser under the B4 loader: a bad link / missing DSO shows up as 126/127, not as a
# usage error.  (Anything stronger needs libstd, i.e. the next rung.)
set +e
"${MC}" >/dev/null 2>&1
mcrc=$?
set -e
if [ ${mcrc} -ge 126 ]; then
  echo "MRUSTC-GATE-4: FAIL (minicargo could not be executed, rc=${mcrc} — bad interpreter or missing DSO)" >&2
  exit 1
fi
echo "MRUSTC-GATE-4: PASS (minicargo executes under the B4 loader, rc=${mcrc})" >&2

# ============================================================================================
# BYTE SEAL — self-arming.  mrustc.answers ships UNPINNED because the shas are not knowable
# until two green CS builds have run.  The moment a real `<64 hex>  <path>` line is added, this
# gate becomes fail-shut with NO code change.  That is the deliberate difference from the
# bedrock rungs, whose seal line is commented out and therefore inert until someone remembers.
# ============================================================================================
ANS="${BUILDROOT}/mrustc.answers"
if grep -Eq '^[0-9a-f]{64}  ' "${ANS}"; then
  if ( cd "${OUTPUT_DIR}" && sha256sum -c "${ANS}" ); then
    echo "MRUSTC-SEAL: PASS (byte-identical to the pinned answers)" >&2
  else
    echo "MRUSTC-SEAL: FAIL (output drifted from mrustc.answers)" >&2
    exit 1
  fi
else
  echo "MRUSTC-SEAL: NOT SEALED — mrustc.answers carries no pins. This rung is GREEN, not SEALED." >&2
fi
