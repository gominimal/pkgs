#!/bin/sh
# build.sh: mrustc 0.12.0 (bin/mrustc + bin/minicargo) compiled with the gcc-15.2.0-glibc g++
# against the glibc-bedrock-2.42 sysroot. Installs usr/bin/{mrustc,minicargo} and ships
# archive-zerolen-skip.sh under usr/share/mrustc/patches/ for the rustc-1.90.0 recipe.
# phases: P0 preconditions, P0b offline stubs, P1 unpack + patches + compiler wrappers,
# P2 determinism patch, P3 build + install, P4 functional gates, byte seal
set -ex

# /build may persist between runs; start from an empty OUTPUT_DIR so a partial install is not
# captured. Pure coreutils: findutils is not in every sandbox.
if [ -n "$OUTPUT_DIR" ] && [ -d "$OUTPUT_DIR" ]; then
  for _e in "$OUTPUT_DIR"/* "$OUTPUT_DIR"/.[!.]* "$OUTPUT_DIR"/..?*; do [ -e "$_e" ] || [ -L "$_e" ] && rm -r "$_e"; done
fi
mkdir -p "$OUTPUT_DIR"

VERSION="${MINIMAL_ARG_VERSION:-0.12.0}"
COMMIT="${MINIMAL_ARG_COMMIT:-1d552cadf1c58bce8b9b431a5714dcea113dde38}"
TARBALL="mrustc-${VERSION}-git1d552ca.tar" # commit-qualified basename; archive prefix is mrustc-${VERSION}/
SRC="mrustc-${VERSION}"
BUILDROOT="$(pwd)"

# Source sha, re-asserted here in addition to build.ncl.
SRC_SHA=1b8a2772e65b283ccbd42cb6a0e94dd2239e59bd4eb866d44405d6b5a0c33314

# An unset MRUSTC_TARGET_VER only warns and falls back to 1.29 mode (src/main.cpp:995), so it
# is pinned; the gate program uses the 1.74+ four-argument lang_start shape.
TARGET_VER=1.90
# aarch64 needs -mno-outline-atomics: mrustc emits compiler_builtins' asm!(noreturn)
# outline-atomics helpers as unconstrained __asm__ in ordinary C functions, and gcc's default
# outline-atomics call them and crash. Inlining atomics makes the helpers dead code.
# x86 gcc rejects the flag.
case "$(uname -m)" in
  x86_64)
    TRIPLE=x86_64-unknown-linux-gnu
    CCTRIPLE=x86_64-linux-gnu      # Target_GetCurSpec().m_backend_c.m_c_compiler (src/trans/target.cpp:440)
    LOADER_SO=ld-linux-x86-64.so.2
    ARCH_CFLAGS=""
    ;;
  aarch64)
    TRIPLE=aarch64-unknown-linux-gnu
    CCTRIPLE=aarch64-linux-gnu
    LOADER_SO=ld-linux-aarch64.so.1
    # +crc: rustc enables the crc target feature per function; the C backend has no
    # per-function targets, so enable it translation-unit-wide. Runtime use stays hwcaps-gated.
    ARCH_CFLAGS="-mno-outline-atomics -march=armv8-a+crc"
    ;;
  *) echo "mrustc: unsupported arch $(uname -m)" >&2; exit 1 ;;
esac

GCC_VERSION=15.2.0
SR=/usr/lib/glibc-bedrock-2.42     # versioned glibc sysroot: headers + crt + libs + kernel UAPI
LOADER="${SR}/lib/${LOADER_SO}"

# --- P0 preconditions ---
BGCC="$(command -v gcc || true)"
BGXX="$(command -v g++ || command -v ${CCTRIPLE}-g++ || true)"
[ -n "${BGCC}" ] || { echo "mrustc: gcc not on PATH" >&2; exit 1; }
[ -n "${BGXX}" ] || { echo "mrustc: g++ not on PATH" >&2; exit 1; }
for t in as ld ar ranlib objcopy strip make sed grep tar sha256sum; do
  command -v "$t" >/dev/null 2>&1 || { echo "mrustc: '$t' not on PATH" >&2; exit 1; }
done

# The host compiler must be the gcc-15.2.0-glibc g++, not an ambient one.
GXXVER="$("${BGXX}" -dumpversion 2>/dev/null || echo unknown)"
[ "${GXXVER}" = "${GCC_VERSION}" ] || {
  echo "mrustc: g++ -dumpversion = '${GXXVER}', expected '${GCC_VERSION}' (gcc-15.2.0-glibc)." >&2
  echo "              Refusing to build: an unexpected host compiler makes this edge meaningless." >&2
  exit 1; }

# glibc sysroot. This gcc has no --with-native-system-header-dir, so libc headers are reached
# only through the explicit -isystem chain below.
[ -e "${SR}/lib/libc.so" ]        || { echo "mrustc: glibc sysroot missing at ${SR} (libc.so)" >&2; exit 1; }
[ -f "${SR}/lib/crt1.o" ]         || { echo "mrustc: glibc startfiles missing at ${SR}/lib (crt1.o)" >&2; exit 1; }
[ -f "${SR}/lib/Scrt1.o" ]        || { echo "mrustc: glibc PIE startfiles missing at ${SR}/lib (Scrt1.o)" >&2; exit 1; }
[ -e "${LOADER}" ]                || { echo "mrustc: glibc loader missing at ${LOADER}" >&2; exit 1; }
[ -f "${SR}/include/stdio.h" ]    || { echo "mrustc: glibc headers missing at ${SR}/include" >&2; exit 1; }
# The sysroot co-locates the kernel UAPI headers (glibc-bedrock-2.42/build.sh:163).
[ -d "${SR}/include/linux" ]      || { echo "mrustc: kernel UAPI not co-located in ${SR}/include (expected linux/)" >&2; exit 1; }

# C++ runtime + headers
CB="/usr/include/c++/${GCC_VERSION}"
[ -d "${CB}" ]                    || { echo "mrustc: C++ headers missing at ${CB}" >&2; exit 1; }
[ -f "${CB}/${CCTRIPLE}/bits/c++config.h" ] || { echo "mrustc: target C++ config missing at ${CB}/${CCTRIPLE}" >&2; exit 1; }
ls /usr/lib/libstdc++.so.6* >/dev/null 2>&1 || { echo "mrustc: libstdc++.so.6 missing at /usr/lib" >&2; exit 1; }
# mrustc's emitted C links `-l atomic` unconditionally (BACKEND_C_OPTS_GNU, src/trans/target.cpp:424).
ls /usr/lib/libatomic.so* >/dev/null 2>&1 || { echo "mrustc: libatomic missing — mrustc codegen links '-l atomic' unconditionally" >&2; exit 1; }

# zlib (Makefile:45 LIBS := -lz)
[ -f /usr/include/zlib.h ]        || { echo "mrustc: zlib.h missing at /usr/include" >&2; exit 1; }
ls /usr/lib/libz.so* >/dev/null 2>&1 || { echo "mrustc: libz.so missing at /usr/lib" >&2; exit 1; }

# --- P0b offline stubs ---
# curl/wget/git stubs exit non-zero and record a tripwire; checked after the build and gates.
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

# --- P1 unpack + patches + sysroot harness ---
have_sha="$(sha256sum < "${TARBALL}" | cut -d' ' -f1)"
[ "${have_sha}" = "${SRC_SHA}" ] || {
  echo "mrustc: FATAL tarball sha ${have_sha} != pinned ${SRC_SHA}" >&2; exit 1; }

tar --no-same-owner -xf "${TARBALL}"
[ -d "${SRC}" ] || { echo "mrustc: FATAL tarball did not unpack to ${SRC}/" >&2; exit 1; }

# Version constants live in src/version.cpp:11-13.
for f in Makefile minicargo.mk src/version.cpp samples/no_core-1_90.rs tools/minicargo/Makefile tools/common/Makefile; do
  [ -f "${SRC}/${f}" ] || { echo "mrustc: FATAL expected source file missing: ${f}" >&2; exit 1; }
done
grep -q '^#define VERSION_MAJOR   0$' "${SRC}/src/version.cpp" || { echo "mrustc: FATAL VERSION_MAJOR != 0" >&2; exit 1; }
grep -q '^#define VERSION_MINOR   12$' "${SRC}/src/version.cpp" || { echo "mrustc: FATAL VERSION_MINOR != 12 (not the 0.12 tree)" >&2; exit 1; }

# hir-ord-unevaluated.patch: upstream backport replacing the ConstGeneric_Unevaluated::ord TODO
# (hit by aarch64 libcore) with the string-compare fallback. Applied only if the TODO is present
# (the pinned master commit already carries the fix); the TODO must be gone afterwards.
if grep -q 'Compare non-expanded array sizes' "${SRC}/src/hir/hir.cpp"; then
  patch -p1 -d "${SRC}" < hir-ord-unevaluated.patch \
    || { echo "mrustc: FATAL hir-ord-unevaluated.patch did not apply" >&2; exit 1; }
fi
grep -q 'Compare non-expanded array sizes' "${SRC}/src/hir/hir.cpp" \
  && { echo "mrustc: FATAL the ord TODO survives after patching" >&2; exit 1; }

# aarch64-support.patch: applied on both arches because it also touches shared code paths
# (see its header). The ctpop fix has a grep-stable signature in the emitted-C source.
patch -p1 -d "${SRC}" < aarch64-support.patch \
  || { echo "mrustc: FATAL aarch64-support.patch did not apply" >&2; exit 1; }
grep -q '__builtin_popcountll((uint64_t)(' "${SRC}/src/trans/codegen_c.cpp" \
  || { echo "mrustc: FATAL aarch64-support.patch applied but the ctpop fix signature is missing" >&2; exit 1; }

# libc.so is a linker script with baked staging paths; regenerate a corrected copy and put it
# first on the library path (same fixup as gcc-15.2.0-glibc/build.sh).
FIXLIB="${BUILDROOT}/glibc-fixlib"; mkdir -p "${FIXLIB}"
sed -E "s@[^ ()]*/(libc\.so\.6|libc_nonshared\.a|ld-linux-x86-64\.so\.2|ld-linux-aarch64\.so\.1)@${SR}/lib/\1@g" \
  "${SR}/lib/libc.so" > "${FIXLIB}/libc.so"
if grep -q '/build/output' "${FIXLIB}/libc.so"; then
  echo "mrustc: libc.so linker-script fixup failed (staging paths survive)" >&2; exit 1
fi

GIX="$("${BGXX}" -print-file-name=include)"
[ -f "${GIX}/stdint.h" ] || { echo "mrustc: gcc internal headers not at '${GIX}'" >&2; exit 1; }

# /usr/include is written by several deps in nondeterministic order; copy the two zlib headers
# into a private dir instead of putting /usr/include on the include path.
ZINC="${BUILDROOT}/zinc"; mkdir -p "${ZINC}"
cp /usr/include/zlib.h /usr/include/zconf.h "${ZINC}/"

CXXINC="-nostdinc -nostdinc++ -isystem ${CB} -isystem ${CB}/${CCTRIPLE} -isystem ${CB}/backward -isystem ${GIX} -isystem ${ZINC} -isystem ${SR}/include"
CINC="-nostdinc -isystem ${GIX} -isystem ${SR}/include"
# --dynamic-linker: the sandbox has no /lib64 symlink, and the gates execute the binaries.
# -rpath so bin/mrustc runs without LD_LIBRARY_PATH. --build-id=none for byte-seal parity.
LNK="-L${FIXLIB} -B${SR}/lib -L${SR}/lib -L/usr/lib -Wl,--dynamic-linker=${LOADER} -Wl,-rpath,${SR}/lib:/usr/lib -Wl,--build-id=none"

# --- compiler wrappers ---
# mrustc builds its own CC argv (src/trans/codegen_c.cpp:1277-1392) with no hook for
# -isystem/-L, so $CC must be a wrapper.
WRAP="${BUILDROOT}/wrap"; mkdir -p "${WRAP}"

cat > "${WRAP}/bedrock-c++" <<EOF
#!/bin/sh
# Compile-only invocations get include flags only; link invocations also get the sysroot link flags.
case " \$* " in
  *" -c "*) exec "${BGXX}" ${CXXINC} ${ARCH_CFLAGS} "\$@" ;;
esac
exec "${BGXX}" ${CXXINC} ${ARCH_CFLAGS} "\$@" ${LNK}
EOF

# The CC mrustc shells out to at codegen time. It logs every invocation; GATE 3 asserts the
# log is non-empty.
cat > "${WRAP}/bedrock-cc" <<EOF
#!/bin/sh
echo "cc \$*" >> "${BUILDROOT}/ccwrap.log"
case " \$* " in
  *" -c "*) exec "${BGCC}" ${CINC} ${ARCH_CFLAGS} "\$@" ;;
esac
exec "${BGCC}" ${CINC} ${ARCH_CFLAGS} "\$@" ${LNK}
EOF
chmod 0755 "${WRAP}/bedrock-c++" "${WRAP}/bedrock-cc"

# --- P2 determinism patch (Makefile:190) ---
cd "${SRC}"

# Five `$(shell ...)` calls, each occurring exactly once. Plain BRE: no needle contains
# . * [ ] \ ^, and `$` is literal when not final.
sed -i \
 -e 's@$(shell git show --pretty=%H -s --no-show-signature)@$(MRUSTC_GIT_FULLHASH)@' \
 -e 's@$(shell git symbolic-ref -q --short HEAD || git describe --tags --exact-match)@$(MRUSTC_GIT_BRANCH)@' \
 -e 's@$(shell git show -s --pretty=%h --no-show-signature)@$(MRUSTC_GIT_SHORTHASH)@' \
 -e 's@$(shell env LC_TIME=C date -u +"%a, %e %b %Y %T +0000")@$(MRUSTC_BUILDTIME)@' \
 -e 's@$(shell git diff-index --quiet HEAD; echo $$?)@$(MRUSTC_GIT_ISDIRTY)@' \
 Makefile

# Fail if upstream reshapes that line rather than silently reintroducing a wall-clock stamp.
if grep -qE 'shell git|shell env|date -u' Makefile; then
  echo "mrustc: FATAL residual wall-clock/git shell-out in Makefile after the determinism patch:" >&2
  grep -nE 'shell git|shell env|date -u' Makefile >&2
  exit 1
fi
for v in MRUSTC_GIT_FULLHASH MRUSTC_GIT_BRANCH MRUSTC_GIT_SHORTHASH MRUSTC_BUILDTIME MRUSTC_GIT_ISDIRTY; do
  grep -q "\$(${v})" Makefile || { echo "mrustc: FATAL determinism patch did not install \$(${v})" >&2; exit 1; }
done

# Plain `date` ignores SOURCE_DATE_EPOCH; derive the buildtime from it in upstream's format.
MRUSTC_BUILDTIME="$(LC_ALL=C date -u -d "@${SOURCE_DATE_EPOCH:-0}" +'%a, %e %b %Y %T +0000')"
MRUSTC_GIT_FULLHASH="${COMMIT}"
MRUSTC_GIT_SHORTHASH="$(echo "${COMMIT}" | cut -c1-7)"
MRUSTC_GIT_BRANCH="v${VERSION}"
# Must be non-empty: src/version.cpp:26 is `bool gbVersion_GitDirty = VERSION_GIT_ISDIRTY;`,
# an unquoted macro, so an empty value is a syntax error.
MRUSTC_GIT_ISDIRTY=0
export MRUSTC_BUILDTIME MRUSTC_GIT_FULLHASH MRUSTC_GIT_SHORTHASH MRUSTC_GIT_BRANCH MRUSTC_GIT_ISDIRTY

# --- P3 build + install ---
JOBS="$(nproc 2>/dev/null || echo 4)"

# MRUSTC_CCACHE must stay unset (src/trans/codegen_c.cpp:1491).
unset MRUSTC_CCACHE CFLAGS CXXFLAGS LDFLAGS RUSTFLAGS 2>/dev/null || true

# Command-line variables reach the `$(MAKE) -C tools/common` sub-make via MAKEFLAGS.
MK="CXX=${WRAP}/bedrock-c++ AR=ar OBJCOPY=objcopy STRIP=strip"
make -j"${JOBS}" ${MK} all
make -j"${JOBS}" ${MK} -C tools/minicargo

[ -x bin/mrustc ]    || { echo "mrustc: FATAL bin/mrustc not produced" >&2; exit 1; }
[ -x bin/minicargo ] || { echo "mrustc: FATAL bin/minicargo not produced" >&2; exit 1; }
for b in bin/mrustc bin/minicargo; do
  magic="$(head -c 4 "$b" | od -An -tx1 | tr -d ' \n')"
  [ "${magic}" = "7f454c46" ] || { echo "mrustc: FATAL ${b} is not an ELF (magic=${magic})" >&2; exit 1; }
done

# --- offline tripwire ---
if [ -e "${BUILDROOT}/NETWORK-TRIPWIRE" ]; then
  echo "mrustc: FATAL the build attempted a network fetch:" >&2
  cat "${BUILDROOT}/NETWORK-TRIPWIRE" >&2
  exit 1
fi
echo "MRUSTC-OFFLINE: PASS (no curl/wget/git invocation during the build)" >&2

# --- determinism proof ---
# The buildtime string lives in .rodata and survives strip. Rebuild version.o at a later
# wall-clock instant and require bin/mrustc to be byte-identical.
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

# --- install ---
mkdir -p "${OUTPUT_DIR}/usr/bin" "${OUTPUT_DIR}/usr/share/mrustc/patches"
cp bin/mrustc bin/minicargo "${OUTPUT_DIR}/usr/bin/"
chmod 0755 "${OUTPUT_DIR}/usr/bin/mrustc" "${OUTPUT_DIR}/usr/bin/minicargo"

# Not applied here (no rustc source at this scope); shipped for the rustc-1.90.0 recipe.
cp "${BUILDROOT}/archive-zerolen-skip.sh" "${OUTPUT_DIR}/usr/share/mrustc/patches/"
chmod 0755 "${OUTPUT_DIR}/usr/share/mrustc/patches/archive-zerolen-skip.sh"

# Fixed constants only.
cat > "${OUTPUT_DIR}/usr/share/mrustc/BUILDINFO" <<EOF
mrustc-version: ${VERSION}
mrustc-commit: ${COMMIT}
source-tarball-sha256: ${SRC_SHA}
host-cxx: gcc-15.2.0-glibc, g++ ${GXXVER}
host-sysroot: ${SR} (glibc-bedrock-2.42)
host-binutils: binutils-2.46-glibc
version-buildtime: ${MRUSTC_BUILDTIME}
mrustc-target-ver: ${TARGET_VER}
scope: mrustc + minicargo only (no libstd, no rustc, no LLVM)
seal-status: see mrustc.answers
EOF

# --- P4 functional gates, run on the installed binaries from ${OUTPUT_DIR} ---
# mrustc lowers Rust to C, shells out to the wrapped gcc, links, and the result is executed.
MR="${OUTPUT_DIR}/usr/bin/mrustc"
MC="${OUTPUT_DIR}/usr/bin/minicargo"
GATE="${BUILDROOT}/gate"; mkdir -p "${GATE}"

export MRUSTC_TARGET_VER="${TARGET_VER}"
# CC_<triple> takes priority over CC (codegen_c.cpp:1284-1292); set both.
export "CC_$(printf %s "${CCTRIPLE}" | tr - _)=${WRAP}/bedrock-cc"
export CC="${WRAP}/bedrock-cc"

# --- GATE 1: mrustc compiles a self-contained #![no_core] program, gcc links it, it runs ---
# Not `make test`: minicargo.mk:224 curls rustc-1.29.0-src.tar.gz. Not samples/no_core-1_90.rs:
# build-1.90.0.sh:25 compiles that with the mrustc-built rustc.
# gate.rs declares #[lang="RangeFull"] itself so static_borrow_constants.cpp:55-66's lookup
# succeeds without a core crate; see gate.rs.
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

# Offline re-check after the gate: the P3 check ran before any gate executed.
if [ -e "${BUILDROOT}/NETWORK-TRIPWIRE" ]; then
  echo "mrustc: FATAL a network fetch was attempted (P4/gate phase):" >&2
  cat "${BUILDROOT}/NETWORK-TRIPWIRE" >&2; exit 1
fi


# --- GATE 3: mrustc really shelled out to the wrapped gcc for codegen ---
if [ -s "${BUILDROOT}/ccwrap.log" ]; then
  ccn="$(wc -l < "${BUILDROOT}/ccwrap.log" | tr -d ' ')"
  echo "MRUSTC-GATE-3: PASS (mrustc invoked the pinned gcc ${ccn}x for C codegen)" >&2
else
  echo "MRUSTC-GATE-3: FAIL (mrustc never invoked \$CC — the gate binaries did not come from our gcc)" >&2
  exit 1
fi

# --- GATE 4: minicargo loads and runs under the sysroot loader ---
# No meaningful no-arg action exists; a bad link or missing DSO shows up as rc 126/127.
set +e
"${MC}" >/dev/null 2>&1
mcrc=$?
set -e
if [ ${mcrc} -ge 126 ]; then
  echo "MRUSTC-GATE-4: FAIL (minicargo could not be executed, rc=${mcrc} — bad interpreter or missing DSO)" >&2
  exit 1
fi
echo "MRUSTC-GATE-4: PASS (minicargo executes under the glibc loader, rc=${mcrc})" >&2

# --- byte seal ---
# Arms itself once mrustc.answers contains a `<sha256>  <path>` line; no code change needed.
ANS="${BUILDROOT}/mrustc.answers"
if grep -Eq '^[0-9a-f]{64}  ' "${ANS}"; then
  if ( cd "${OUTPUT_DIR}" && sha256sum -c "${ANS}" ); then
    echo "MRUSTC-SEAL: PASS (byte-identical to the pinned answers)" >&2
  else
    echo "MRUSTC-SEAL: FAIL (output drifted from mrustc.answers)" >&2
    exit 1
  fi
else
  echo "MRUSTC-SEAL: no pins present in mrustc.answers; seal not checked" >&2
fi
