#!/bin/sh
# build.sh: rustc 1.90.0 + cargo + libstd, compiled by the mrustc/minicargo binaries from
# packages/mrustc. Installs to the private prefix usr/lib/mrustc-rust-1.90.0/, which the
# rustc-1.91.1 recipe consumes as its stage0.
# phases: P0 preconditions, P0b offline stubs, P1 unpack + compiler wrappers, P2 rustc source,
# P3 LLVM (cmake), P4 minicargo.mk LIBS/rustc/cargo, P5 run_rustc stages 1-4, P6 install,
# P7 functional gates, P8 byte seal
set -ex

# /build may persist between runs; start from an empty OUTPUT_DIR so a partial install is not
# captured. Pure coreutils: findutils is not in every sandbox.
if [ -n "$OUTPUT_DIR" ] && [ -d "$OUTPUT_DIR" ]; then
  for _e in "$OUTPUT_DIR"/* "$OUTPUT_DIR"/.[!.]* "$OUTPUT_DIR"/..?*; do [ -e "$_e" ] || [ -L "$_e" ] && rm -r "$_e"; done
fi
mkdir -p "$OUTPUT_DIR"

VERSION="${MINIMAL_ARG_VERSION:-1.90.0}"
MRUSTC_VERSION="${MINIMAL_ARG_MRUSTC_VERSION:-0.12.0}"
MRUSTC_COMMIT="${MINIMAL_ARG_MRUSTC_COMMIT:-1d552cadf1c58bce8b9b431a5714dcea113dde38}"

BUILDROOT="$(pwd)"
MTAR="mrustc-${MRUSTC_VERSION}-git1d552ca.tar" # commit-qualified basename; archive prefix is mrustc-${MRUSTC_VERSION}/
MSRC="${BUILDROOT}/mrustc-${MRUSTC_VERSION}"
RTAR="rustc-${VERSION}-src.tar.gz"
RSRC="rustc-${VERSION}-src"          # relative to ${MSRC}; minicargo.mk hardcodes this shape
OUTDIR="output-${VERSION}"

# Source shas, re-asserted here in addition to build.ncl.
MTAR_SHA=1b8a2772e65b283ccbd42cb6a0e94dd2239e59bd4eb866d44405d6b5a0c33314
RTAR_SHA=799a9f9cba4ed5351e071048bcf6b5560755d9009648def33a407dd4961f9b7e

# aarch64 needs -mno-outline-atomics: mrustc emits compiler_builtins' asm!(noreturn)
# outline-atomics helpers as unconstrained __asm__ in ordinary C functions, and gcc's default
# outline-atomics call them and crash. Inlining atomics makes the helpers dead code.
# x86 gcc rejects the flag.
case "$(uname -m)" in
  x86_64)
    TRIPLE=x86_64-unknown-linux-gnu
    CCTRIPLE=x86_64-linux-gnu
    LOADER_SO=ld-linux-x86-64.so.2
    STD_ARCH=x86_64
    ARCH_CFLAGS=""
    ;;
  aarch64)
    TRIPLE=aarch64-unknown-linux-gnu
    CCTRIPLE=aarch64-linux-gnu
    LOADER_SO=ld-linux-aarch64.so.1
    STD_ARCH=aarch64
    # +crc: rustc enables the crc target feature per function; the C backend has no
    # per-function targets, so enable it translation-unit-wide. Runtime use stays hwcaps-gated.
    ARCH_CFLAGS="-mno-outline-atomics -march=armv8-a+crc"
    ;;
  *) echo "rustc: unsupported arch $(uname -m)" >&2; exit 1 ;;
esac
TARGET_VER=1.90                      # not 1.90.0: src/main.cpp:990-991 exits on an unknown value
GCC_VERSION=15.2.0
SR=/usr/lib/glibc-bedrock-2.42       # versioned glibc sysroot
LOADER="${SR}/lib/${LOADER_SO}"

MR=/usr/bin/mrustc                   # from packages/mrustc
MC=/usr/bin/minicargo
ZEROLEN=/usr/share/mrustc/patches/archive-zerolen-skip.sh

DST="${OUTPUT_DIR}/usr/lib/mrustc-rust-${VERSION}"

JOBS="$(nproc 2>/dev/null || echo 4)"

# --- P0 preconditions ---
BGCC="$(command -v gcc || true)"
BGXX="$(command -v g++ || command -v ${CCTRIPLE}-g++ || true)"
[ -n "${BGCC}" ] || { echo "rustc: gcc not on PATH" >&2; exit 1; }
[ -n "${BGXX}" ] || { echo "rustc: g++ not on PATH" >&2; exit 1; }

# packages/mrustc's tool list plus patch, cmake, perl, python3, pkg-config, find, cmp, gzip.
for t in as ld ar ranlib objcopy strip readelf make sed grep tar sha256sum \
         patch cmake perl python3 pkg-config find cmp gzip; do
  command -v "$t" >/dev/null 2>&1 || { echo "rustc: '$t' not on PATH" >&2; exit 1; }
done

GXXVER="$("${BGXX}" -dumpversion 2>/dev/null || echo unknown)"
[ "${GXXVER}" = "${GCC_VERSION}" ] || {
  echo "rustc: g++ -dumpversion = '${GXXVER}', expected '${GCC_VERSION}' (gcc-15.2.0-glibc)." >&2
  echo "            Refusing to build: an unexpected host compiler makes this build meaningless." >&2
  exit 1; }

# glibc sysroot
[ -e "${SR}/lib/libc.so" ]     || { echo "rustc: glibc sysroot missing at ${SR} (libc.so)" >&2; exit 1; }
[ -f "${SR}/lib/crt1.o" ]      || { echo "rustc: glibc startfiles missing (crt1.o)" >&2; exit 1; }
[ -f "${SR}/lib/Scrt1.o" ]     || { echo "rustc: glibc PIE startfiles missing (Scrt1.o)" >&2; exit 1; }
[ -e "${LOADER}" ]             || { echo "rustc: glibc loader missing at ${LOADER}" >&2; exit 1; }
[ -f "${SR}/include/stdio.h" ] || { echo "rustc: glibc headers missing at ${SR}/include" >&2; exit 1; }
[ -d "${SR}/include/linux" ]   || { echo "rustc: kernel UAPI not co-located in ${SR}/include" >&2; exit 1; }

# C++ runtime + headers (LLVM is C++).
CB="/usr/include/c++/${GCC_VERSION}"
[ -d "${CB}" ] || { echo "rustc: C++ headers missing at ${CB}" >&2; exit 1; }
[ -f "${CB}/${CCTRIPLE}/bits/c++config.h" ] || { echo "rustc: target C++ config missing" >&2; exit 1; }
ls /usr/lib/libstdc++.so.6* >/dev/null 2>&1 || { echo "rustc: libstdc++.so.6 missing" >&2; exit 1; }
# mrustc's emitted C links `-l atomic` unconditionally (src/trans/target.cpp:424).
ls /usr/lib/libatomic.so*  >/dev/null 2>&1 || { echo "rustc: libatomic missing" >&2; exit 1; }
[ -f /usr/include/zlib.h ] || { echo "rustc: zlib.h missing" >&2; exit 1; }

# The mrustc/minicargo binaries and the archive patch script from packages/mrustc.
[ -x "${MR}" ] || { echo "rustc: ${MR} missing — the mrustc package is required" >&2; exit 1; }
[ -x "${MC}" ] || { echo "rustc: ${MC} missing — the mrustc package is required" >&2; exit 1; }
[ -x "${ZEROLEN}" ] || { echo "rustc: ${ZEROLEN} missing (packages/mrustc/build.sh:273 ships it)" >&2; exit 1; }

# `$(MRUSTC)` is prerequisite-only on every target built here; minicargo selects mrustc itself
# (os.cpp:419 MRUSTC_PATH, else its own sibling). `mrustc -vV` (src/main.cpp:1015) is the only
# identity check on the compiler that actually runs.
MRVV="$("${MR}" -vV 2>&1 || true)"
echo "${MRVV}" | grep -qF "commit-hash: ${MRUSTC_COMMIT}" || {
  echo "rustc: ${MR} does not report commit-hash ${MRUSTC_COMMIT}." >&2
  echo "            Got:" >&2; echo "${MRVV}" >&2
  echo "            Refusing to build against an unidentified mrustc." >&2
  exit 1; }
echo "rustc MRUSTC: mrustc identity OK (commit ${MRUSTC_COMMIT})" >&2

# --- P0b offline stubs ---
# curl/wget stubs exit non-zero. A real curl is in this rootfs (cmake imports ../curl), so the
# stub must win by PATH order; asserted below.
# git: only local, network-free probes are allowed (rev-parse HEAD/--git-dir/--show-toplevel,
# --version). Three vendored build.rs run `git submodule update --init` behind a `.git` marker
# check (suppressed in P2); wasm-bindgen-shared and cranelift-codegen run a bare
# `git rev-parse HEAD` whose failure they handle. Any other git argv fails the build.
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
# Only local probes (rev-parse HEAD/--git-dir/--show-toplevel, --version) are allowed; anything else fails.
case "\$1 \$2" in
  "rev-parse HEAD"|"rev-parse --git-dir"|"rev-parse --show-toplevel")
    echo "git \$*" >> "${BUILDROOT}/GIT-LOCAL.log"; exit 1 ;;  # real git's out-of-repo behaviour
esac
if [ "\$1" = "--version" ]; then
  echo "git \$*" >> "${BUILDROOT}/GIT-LOCAL.log"; echo "git version 0.0.0-bedrock-stub"; exit 0
fi
echo "git \$*" >> "${BUILDROOT}/NETWORK-TRIPWIRE"
echo "rustc: FATAL — the build invoked git with a non-local argv: \$*" >&2
exit 1
EOF
chmod 0755 "${STUBS}/git"

PATH="${STUBS}:${PATH}"; export PATH
[ "$(command -v curl)" = "${STUBS}/curl" ] || {
  echo "rustc: FATAL the curl stub is NOT shadowing the real curl (packages/cmake pulls one in)." >&2
  echo "      command -v curl = $(command -v curl)" >&2; exit 1; }
[ "$(command -v git)" = "${STUBS}/git" ] || {
  echo "rustc: FATAL the git stub is NOT first on PATH" >&2; exit 1; }

# CARGO_NET_OFFLINE makes any attempted fetch a hard error; GIT_CEILING_DIRECTORIES stops
# repository discovery walking out of the build root.
export CARGO_NET_OFFLINE=true
export GIT_CEILING_DIRECTORIES="${BUILDROOT}"
export GIT_CONFIG_NOSYSTEM=1
export GIT_TERMINAL_PROMPT=0

# cargo's config walk ascends to /; an ambient .cargo/config could re-enable the network.
d="${BUILDROOT}"
while [ "${d}" != "/" ] && [ -n "${d}" ]; do
  [ -e "${d}/.cargo" ] && { echo "rustc: FATAL ambient .cargo/ found at ${d} — cargo would merge it" >&2; exit 1; }
  d="$(dirname "${d}")"
done
[ -e "/.cargo" ] && { echo "rustc: FATAL ambient /.cargo/ present" >&2; exit 1; }
unset d

# --- P1 unpack the mrustc tree (used as data only) + sysroot harness ---
have="$(sha256sum < "${MTAR}" | cut -d' ' -f1)"
[ "${have}" = "${MTAR_SHA}" ] || { echo "rustc: FATAL mrustc tarball sha ${have} != ${MTAR_SHA}" >&2; exit 1; }
have="$(sha256sum < "${RTAR}" | cut -d' ' -f1)"
[ "${have}" = "${RTAR_SHA}" ] || { echo "rustc: FATAL rustc tarball sha ${have} != ${RTAR_SHA}" >&2; exit 1; }

tar --no-same-owner -xf "${MTAR}"
[ -d "${MSRC}" ] || { echo "rustc: FATAL mrustc tarball did not unpack to ${MSRC}/" >&2; exit 1; }

# Tree data this recipe reads. The binaries come from packages/mrustc; `make -f Makefile all`
# is never run here.
for f in minicargo.mk rust-version rustc-${VERSION}-src.patch rustc-${VERSION}-overrides.toml \
         script-overrides/stable-${VERSION}-linux lib/libproc_macro \
         run_rustc/Makefile run_rustc/rustc_proxy.sh samples/hello.rs; do
  [ -e "${MSRC}/${f}" ] || { echo "rustc: FATAL mrustc tree data missing: ${f}" >&2; exit 1; }
done
# minicargo.mk:16-17 derives OUTDIR_SUF from rust-version.
grep -qx '1.29.0' "${MSRC}/rust-version" || {
  echo "rustc: FATAL mrustc rust-version is not 1.29.0 — OUTDIR_SUF derivation assumptions broken" >&2; exit 1; }

# libc.so is a linker script with baked staging paths; regenerate a corrected copy.
FIXLIB="${BUILDROOT}/glibc-fixlib"; mkdir -p "${FIXLIB}"
sed -E "s@[^ ()]*/(libc\.so\.6|libc_nonshared\.a|ld-linux-x86-64\.so\.2|ld-linux-aarch64\.so\.1)@${SR}/lib/\1@g" \
  "${SR}/lib/libc.so" > "${FIXLIB}/libc.so"
grep -q '/build/output' "${FIXLIB}/libc.so" && { echo "rustc: libc.so fixup failed" >&2; exit 1; }

GIX="$("${BGXX}" -print-file-name=include)"
[ -f "${GIX}/stdint.h" ] || { echo "rustc: gcc internal headers not at '${GIX}'" >&2; exit 1; }

# /usr/include is written by several deps in nondeterministic order; copy the headers needed
# into a private dir instead of putting /usr/include on the include path.
ZINC="${BUILDROOT}/zinc"; mkdir -p "${ZINC}"
cp /usr/include/zlib.h /usr/include/zconf.h "${ZINC}/"

CXXINC="-nostdinc -nostdinc++ -isystem ${CB} -isystem ${CB}/${CCTRIPLE} -isystem ${CB}/backward -isystem ${GIX} -isystem ${ZINC} -isystem ${SR}/include"
CINC="-nostdinc -isystem ${GIX} -isystem ${ZINC} -isystem ${SR}/include"

# rustc and cargo pass many -L dirs and ld searches them in command-line order, so the fixup
# search paths are prepended and the -Wl options appended.
LPRE="-L${FIXLIB} -B${SR}/lib -L${SR}/lib -L/usr/lib"
LPOST="-Wl,--dynamic-linker=${LOADER} -Wl,-rpath,${SR}/lib:/usr/lib -Wl,--build-id=none"

WRAP="${BUILDROOT}/wrap"; mkdir -p "${WRAP}"

# Both wrappers log every invocation; GATE-6 checks that LLVM went through the C++ wrapper.
cat > "${WRAP}/bedrock-cc" <<EOF
#!/bin/sh
echo "cc \$*" >> "${BUILDROOT}/ccwrap.log"
case " \$* " in
  *" -c "*) exec "${BGCC}" ${CINC} ${ARCH_CFLAGS} ${LPRE} "\$@" ;;
esac
exec "${BGCC}" ${CINC} ${ARCH_CFLAGS} ${LPRE} "\$@" ${LPOST}
EOF
cat > "${WRAP}/bedrock-c++" <<EOF
#!/bin/sh
echo "c++ \$*" >> "${BUILDROOT}/cxxwrap.log"
case " \$* " in
  *" -c "*) exec "${BGXX}" ${CXXINC} ${ARCH_CFLAGS} ${LPRE} "\$@" ;;
esac
exec "${BGXX}" ${CXXINC} ${ARCH_CFLAGS} ${LPRE} "\$@" ${LPOST}
EOF
chmod 0755 "${WRAP}/bedrock-cc" "${WRAP}/bedrock-c++"

CCW="${WRAP}/bedrock-cc"
CXXW="${WRAP}/bedrock-c++"

# MRUSTC_CCACHE must stay unset (src/trans/codegen_c.cpp:1491).
unset MRUSTC_CCACHE CFLAGS CXXFLAGS LDFLAGS RUSTFLAGS 2>/dev/null || true

# An unset MRUSTC_TARGET_VER only warns and falls back to 1.29 mode (src/main.cpp:995).
export MRUSTC_TARGET_VER="${TARGET_VER}"
# Select mrustc explicitly (os.cpp:419) rather than by sibling lookup.
export MRUSTC_PATH="${MR}"
export CC="${CCW}"
export CXX="${CXXW}"
export "CC_$(printf %s "${CCTRIPLE}" | tr - _)=${CCW}"   # takes priority over CC (codegen_c.cpp:1284-1292)

# The built rustc's default linker is the literal `cc` (run_rustc/Makefile:172 passes no
# -C linker=); the sandbox has only `gcc`. Alias cc/c++ to the wrappers.
ln -sf "${CCW}" "${WRAP}/cc"
ln -sf "${CXXW}" "${WRAP}/c++"
PATH="${WRAP}:${PATH}"; export PATH
command -v cc >/dev/null 2>&1 || { echo "mrustc-1.90.0: FATAL cc alias not on PATH" >&2; exit 1; }

# Command-line make variables beat `?=` and `:=` and reach sub-makes via MAKEFLAGS
# (run_rustc/Makefile:127-132 re-enters minicargo.mk).
#   V=                       un-silence recipes (run_rustc/Makefile:115 defaults V to `@`)
#   PARLEVEL                 minicargo.mk:32 and run_rustc/Makefile:16 default to 1 (serial)
#   RUSTC_TARGET/STD_ENV_ARCH  minicargo.mk defaults both to x86_64; the wrong STD_ENV_ARCH
#                            feeds libcore the x86 cfg paths
MKV="RUSTC_VERSION=${VERSION} OUTDIR_SUF=-${VERSION} MRUSTC=${MR} MINICARGO=${MC} \
RUSTC_TARGET=${TRIPLE} STD_ENV_ARCH=${STD_ARCH} \
CC=${CCW} CXX=${CXXW} PARLEVEL=${JOBS} V="

cd "${MSRC}"

# --- P2 rustc source ---
# The tarball must sit at the tree root under the name minicargo.mk:220 builds. That rule has
# no prerequisites, so a pre-placed file is up to date and the curl recipe at :224 never fires.
# Let make extract so the `extracted` and `dl-version` stamps are created.
ln "${BUILDROOT}/${RTAR}" "./${RTAR}" 2>/dev/null \
  || mv "${BUILDROOT}/${RTAR}" "./${RTAR}" 2>/dev/null \
  || cp "${BUILDROOT}/${RTAR}" "./${RTAR}"
[ -f "./${RTAR}" ] || { echo "rustc: FATAL could not place ${RTAR} at the mrustc tree root" >&2; exit 1; }

# RUSTCSRC -> dl-version -> extracted -> tarball; minicargo.mk:229 applies rustc-1.90.0-src.patch.
make -f minicargo.mk ${MKV} RUSTCSRC
[ -d "${RSRC}/vendor" ] || { echo "rustc: FATAL ${RSRC}/vendor absent after extraction" >&2; exit 1; }
[ -f "${RSRC}/src/llvm-project/llvm/CMakeLists.txt" ] || {
  echo "rustc: FATAL ${RSRC}/src/llvm-project/llvm/CMakeLists.txt absent — minicargo.mk:309 has no rule for it" >&2; exit 1; }

# Three vendored build.rs run `git submodule update --init` when a `.git` marker is absent;
# an empty marker suppresses that. cargo's checksum verification covers only files listed in
# .cargo-checksum.json, so adding a file is safe; editing an existing vendored file is not.
# libgit2-sys guards on libgit2/src, which ships, so it needs no marker. Derive this list by
# reading each build.rs guard, not by pattern-matching on `.git`.
for sub in "vendor/curl-sys-0.4.82+curl-8.14.1/curl" \
           "vendor/curl-sys-0.4.79+curl-8.12.0/curl" \
           "vendor/libssh2-sys-0.3.1/libssh2"; do
  # Assert the parent by exact name: a drifted version must fail here, not hours later.
  [ -d "${RSRC}/${sub}" ] || {
    echo "rustc: FATAL expected vendored submodule dir missing: ${sub}" >&2
    echo "      The 1.90.0 lockfile pins these versions.  If upstream drifted, RE-DERIVE the" >&2
    echo "      marker list by reading each vendor/*/build.rs guard.  Do NOT mkdir -p blindly." >&2
    exit 1; }
  [ -e "${RSRC}/${sub}/.git" ] || : > "${RSRC}/${sub}/.git"
done

# archive-zerolen-skip.sh: applied after minicargo.mk's own patch and before output-1.90.0/rustc
# is built. The failure it prevents appears in a log as "failed to map object file" /
# ArchiveBuildFailure, not as a bare SIGABRT.
"${ZEROLEN}" "${RSRC}"
grep -q 'ZEROLEN-SKIP' "${RSRC}/compiler/rustc_codegen_ssa/src/back/archive.rs" || {
  echo "rustc: FATAL archive-zerolen-skip.sh reported success but the marker is absent" >&2; exit 1; }

# --- P3 LLVM via cmake ---
# minicargo.mk:301 passes CMAKE_CXX_COMPILER="$(CXX)" CMAKE_C_COMPILER="$(CC)"; CXX and CC are
# make builtins (g++/cc) that minicargo.mk never assigns, so ${MKV} must override them on the
# command line. GATE-6 checks cxxwrap.log. Built as its own phase for a clean log boundary.
make -f minicargo.mk ${MKV} "${RSRC}/build/bin/llvm-config"
[ -x "${RSRC}/build/bin/llvm-config" ] || { echo "rustc: FATAL llvm-config not produced" >&2; exit 1; }

# --- P4 minicargo.mk: LIBS -> rustc -> cargo ---
# minicargo cannot fetch (manifest.h:210 has_git() is false; no network primitives) and vendor/
# covers every lockfile. MMIR must stay empty: tools/minicargo/build.cpp:1186 hardcodes a
# developer path. `make test`/`local_tests` are not run: at the default version they curl
# rustc-1.29.0-src.tar.gz.
make -f minicargo.mk ${MKV} LIBS
make -f minicargo.mk ${MKV} RUSTC_INSTALL_BINDIR=bin "${OUTDIR}/rustc"
[ -x "${OUTDIR}/rustc" ] || { echo "rustc: FATAL ${OUTDIR}/rustc not produced" >&2; exit 1; }
make -f minicargo.mk ${MKV} "${OUTDIR}/cargo"
[ -x "${OUTDIR}/cargo" ] || { echo "rustc: FATAL ${OUTDIR}/cargo not produced" >&2; exit 1; }

# Smoke only; the gates run in P7 on the installed binaries.
"./${OUTDIR}/rustc" --version

# --- P5 run_rustc: stage 1 (std via minicargo) -> stage 2 (std via cargo) -> stage 3
#     (optimised rustc) -> stage 4 (std matching its ABI) -> cargo ---
# run_rustc/Makefile:162 is the first place the mrustc-built rustc runs, so this is where
# archive-zerolen-skip.sh matters. Offline rests on $(CARGO_HOME)config
# (run_rustc/Makefile:145-151) pointing crates-io at vendored-sources, plus CARGO_NET_OFFLINE.
# MRUSTC/MINICARGO are passed so the minicargo.mk re-entries at :127-132 cannot fall into the
# .PHONY self-rebuild of mrustc.
make -C run_rustc ${MKV}
RRP="run_rustc/${OUTDIR}/prefix"
[ -x "${RRP}/bin/rustc" ]        || { echo "rustc: FATAL run_rustc did not produce ${RRP}/bin/rustc" >&2; exit 1; }
[ -x "${RRP}/bin/rustc_binary" ] || { echo "rustc: FATAL ${RRP}/bin/rustc_binary missing" >&2; exit 1; }
[ -x "${RRP}/bin/cargo" ]        || { echo "rustc: FATAL ${RRP}/bin/cargo missing" >&2; exit 1; }

# --- offline tripwire, checkpoint 1 ---
if [ -e "${BUILDROOT}/NETWORK-TRIPWIRE" ]; then
  echo "rustc: FATAL the build attempted a network fetch:" >&2
  cat "${BUILDROOT}/NETWORK-TRIPWIRE" >&2
  exit 1
fi
if [ -e "${BUILDROOT}/GIT-LOCAL.log" ]; then
  echo "rustc OFFLINE: NOTE — permitted local \`git rev-parse HEAD\` calls occurred:" >&2
  sort -u "${BUILDROOT}/GIT-LOCAL.log" >&2
  echo "              (expected 0; a non-zero count means minicargo's cfg gating admitted" >&2
  echo "               wasm-bindgen-shared.  Harmless — no network verb was permitted.)" >&2
fi
echo "rustc OFFLINE: PASS (no curl/wget, and no network-capable git verb, during the build)" >&2

# --- P6 install ---
# run_rustc/Makefile:227 bakes the absolute build-tree lib path into the bin/rustc wrapper;
# regenerate it $0-relative, then sweep the tree for surviving build paths.
mkdir -p "${DST}/bin" "${DST}/lib" "${OUTPUT_DIR}/usr/share/mrustc-rust-${VERSION}"
# Only bin/ and lib/ ship; $(PREFIX)cargo_home and $(PREFIX)tmp are build scratch.
cp -a "${RRP}/bin/." "${DST}/bin/"
cp -a "${RRP}/lib/." "${DST}/lib/"
# run_rustc/Makefile:259 builds hello_world into BINDIR; test artifact, not a tool.
rm -f "${DST}/bin/hello_world"

# Unquoted heredoc: ${TRIPLE} must expand at install time (rustlib/<triple>/lib is the only
# location of librustc_driver.so); everything else is escaped.
cat > "${DST}/bin/rustc" <<WRAPEOF
#!/bin/sh
d="\$(dirname "\$0")"
LD_LIBRARY_PATH="\${d}/../lib:\${d}/../lib/rustlib/${TRIPLE}/lib\${LD_LIBRARY_PATH:+:\${LD_LIBRARY_PATH}}" \\
  exec "\${d}/rustc_binary" "\$@"
WRAPEOF
chmod 0755 "${DST}/bin/rustc"

# Fail on a surviving build path in any text file. `grep -I` skips binaries: DWARF legitimately
# contains the build root in every .rlib and ELF.
hits="$(find "${OUTPUT_DIR}" -type f -exec grep -I -l -F "${BUILDROOT}" {} + 2>/dev/null || true)"
if [ -n "${hits}" ]; then
  echo "rustc: FATAL build-root paths survive in installed TEXT files:" >&2
  echo "${hits}" >&2
  exit 1
fi

cat > "${OUTPUT_DIR}/usr/share/mrustc-rust-${VERSION}/BUILDINFO" <<EOF
rustc-version: ${VERSION}
rustc-source-sha256: ${RTAR_SHA}
built-by: mrustc ${MRUSTC_VERSION} (commit ${MRUSTC_COMMIT}), consumed from packages/mrustc
mrustc-tarball-sha256: ${MTAR_SHA}
host-cc: gcc-15.2.0-glibc, gcc/g++ ${GXXVER}
host-sysroot: ${SR} (glibc-bedrock-2.42)
host-binutils: binutils-2.46-glibc
target: ${TRIPLE}
scope: LIBS + output-${VERSION}/{rustc,cargo} + run_rustc stages 1-4
patches-applied: rustc-${VERSION}-src.patch (mrustc, minicargo.mk:229), archive-zerolen-skip.sh
seal-status: see rustc-${VERSION}.answers
EOF

# --- P7 functional gates, run on the installed binaries from ${OUTPUT_DIR} ---
# Upstream's own checks are not used: samples/no_core-1_90.rs is compile-only and run_rustc's
# hello_world is exit-status-only and runs before install.
# `set -e` would abort before a bare assert, so every gated command is rc-captured.
RUSTC="${DST}/bin/rustc"
CARGO="${DST}/bin/cargo"
RLIB="${DST}/lib/rustlib/${TRIPLE}/lib"
G="${BUILDROOT}/gate"; mkdir -p "${G}"

# --- GATE-1: identity ---
# run_rustc/Makefile:98 sets CFG_VERSION=$(RUSTC_VERSION)-stable-mrustc; this also proves
# RUSTC_VERSION took (unset would have built 1.29.0).
set +e; RV="$("${RUSTC}" --version 2>&1)"; rc=$?; set -e
[ ${rc} -eq 0 ] || { echo "rustc GATE-1: FAIL (installed rustc did not execute, rc=${rc}) — ${RV}" >&2; exit 1; }
echo "${RV}" | grep -qF "${VERSION}-stable-mrustc" || {
  echo "rustc GATE-1: FAIL — rustc --version = '${RV}', expected to contain '${VERSION}-stable-mrustc'" >&2; exit 1; }
echo "rustc GATE-1: PASS (identity ${RV})" >&2

# --- GATE-2: rlib production ---
# Emitting an rlib runs ArArchiveBuilder::build_inner, the path archive-zerolen-skip.sh patches.
cp "${BUILDROOT}/gatelib.rs" "${G}/gatelib.rs"
set +e
( cd "${G}" && "${RUSTC}" --crate-type=rlib --crate-name=gatelib -L "${RLIB}" gatelib.rs -o libgatelib.rlib ) \
  >"${G}/g2.log" 2>&1
rc=$?
set -e
if [ ${rc} -ne 0 ]; then
  echo "rustc GATE-2: FAIL (rc=${rc}) — could not emit an rlib." >&2
  tail -40 "${G}/g2.log" >&2 || true
  grep -qE 'failed to map object file|ArchiveBuildFailure' "${G}/g2.log" && \
    echo "HINT: zero-length archive member; archive-zerolen-skip.sh did not take." >&2
  exit 1
fi
[ -s "${G}/libgatelib.rlib" ] || { echo "rustc GATE-2: FAIL (rc=0 but no rlib produced)" >&2; exit 1; }
echo "rustc GATE-2: PASS (ArArchiveBuilder wrote a non-empty rlib)" >&2

# --- GATE-3: ten std constructs, compiled and executed ---
# The pass value 42 is only ever the computed sum of ten quantities; each construct also has
# its own exit code so a failure names the construct. c4 calls into the GATE-2 rlib across
# the crate boundary.
cp "${BUILDROOT}/gate190.rs" "${G}/gate190.rs"
set +e
( cd "${G}" && "${RUSTC}" -L "${RLIB}" --extern gatelib="${G}/libgatelib.rlib" gate190.rs -o gate190 ) \
  >"${G}/g3-compile.log" 2>&1
rc=$?
set -e
if [ ${rc} -ne 0 ]; then
  echo "rustc GATE-3: FAIL (rc=${rc}) — the installed rustc could not compile the gate program:" >&2
  tail -60 "${G}/g3-compile.log" >&2 || true
  exit 1
fi
set +e; "${G}/gate190"; rc=$?; set -e
case ${rc} in
  42) : ;;
  111) echo "rustc GATE-3: FAIL — iterator/closure/heap path (Vec+filter+map+sum != 165)" >&2; exit 1 ;;
  112) echo "rustc GATE-3: FAIL — core::fmt / String / str::parse round-trip" >&2; exit 1 ;;
  113) echo "rustc GATE-3: FAIL — BTreeMap/HashMap (Ord, hashing, OS entropy for RandomState)" >&2; exit 1 ;;
  114) echo "rustc GATE-3: FAIL — CROSS-CRATE Box<dyn Trait> vtable dispatch into the rlib" >&2; exit 1 ;;
  115) echo "rustc GATE-3: FAIL — generics + FnMut closure capture" >&2; exit 1 ;;
  116) echo "rustc GATE-3: FAIL — Result + '?' + Option combinators" >&2; exit 1 ;;
  117) echo "rustc GATE-3: FAIL — catch_unwind / UNWINDING through panic_unwind" >&2; exit 1 ;;
  118) echo "rustc GATE-3: FAIL — checked_add/wrapping_add overflow semantics" >&2; exit 1 ;;
  119) echo "rustc GATE-3: FAIL — f64 format + parse round-trip" >&2; exit 1 ;;
  120) echo "rustc GATE-3: FAIL — thread::spawn + join + Arc<Mutex<_>> (pthreads, TLS, atomics)" >&2; exit 1 ;;
  134) echo "rustc GATE-3: FAIL — SIGABRT (rc=134). Suspect a zero-length archive member." >&2; exit 1 ;;
  139) echo "rustc GATE-3: FAIL — SIGSEGV (rc=139). Suspect an rlib/dylib std ABI mismatch." >&2; exit 1 ;;
  126|127) echo "rustc GATE-3: FAIL — rc=${rc}: bad interpreter or missing DSO (loader/rpath)" >&2; exit 1 ;;
  *)   echo "rustc GATE-3: FAIL — gate binary exited ${rc}, expected the computed 42" >&2; exit 1 ;;
esac
echo "rustc GATE-3: PASS (ten std constructs compiled, linked and RAN; computed 42)" >&2

# --- GATE-4: proc macros + dylib std ---
# run_rustc/Makefile:218 is the only step that produces dylib std. Statically linked gates pass
# without it; the rustc-1.91.1 build needs derives, so this gate must stay fail-shut.
cp "${BUILDROOT}/gate_pm.rs" "${G}/gate_pm.rs"
cp "${BUILDROOT}/gate_pm_use.rs" "${G}/gate_pm_use.rs"
set +e
( cd "${G}" && "${RUSTC}" --crate-type=proc-macro --crate-name=gate_pm -L "${RLIB}" gate_pm.rs -o libgate_pm.so ) \
  >"${G}/g4-pm.log" 2>&1
rc=$?
set -e
if [ ${rc} -ne 0 ]; then
  echo "rustc GATE-4: FAIL (rc=${rc}) — could not build a proc-macro crate." >&2
  echo "             This rustc cannot serve as the next rung's stage0 (x.py needs proc-macros)." >&2
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
  echo "rustc GATE-4: FAIL (rc=${rc}) — rustc could not LOAD and EXPAND the proc macro:" >&2
  tail -40 "${G}/g4-use.log" >&2 || true
  exit 1
fi
set +e; "${G}/gate_pm_use"; rc=$?; set -e
[ ${rc} -eq 42 ] || {
  echo "rustc GATE-4: FAIL — proc-macro consumer exited ${rc}, expected the computed 42" >&2
  [ ${rc} -eq 121 ] && echo "             (121 = the macro expanded but produced the wrong value)" >&2
  exit 1; }
echo "rustc GATE-4: PASS (proc-macro crate built as a dylib, dlopen'd, expanded, and RAN)" >&2

# --- GATE-5: cargo drives a two-crate path-dependency build (no registry deps) ---
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
  echo "rustc GATE-5: FAIL (rc=${rc}) — cargo could not drive a two-crate path-dependency build:" >&2
  tail -40 "${G}/g5.log" >&2 || true
  exit 1
fi
set +e; "${CW}/target/release/gateapp"; rc=$?; set -e
[ ${rc} -eq 42 ] || { echo "rustc GATE-5: FAIL — cargo-built binary exited ${rc}, expected the computed 42" >&2; exit 1; }
echo "rustc GATE-5: PASS (cargo resolved a path dep, invoked our rustc, linked, and the binary RAN)" >&2

# --- GATE-6: provenance ---
# (a) the C wrapper was used; (b) LLVM went through the C++ wrapper (covers minicargo.mk:301's
# builtin CXX); (c) rustc_binary's interpreter is the sysroot loader.
[ -s "${BUILDROOT}/ccwrap.log" ] || {
  echo "rustc GATE-6: FAIL — ccwrap.log empty: nothing went through the pinned gcc" >&2; exit 1; }
[ -s "${BUILDROOT}/cxxwrap.log" ] || {
  echo "rustc GATE-6: FAIL — cxxwrap.log empty: the pinned g++ compiled nothing." >&2
  echo "             minicargo.mk:301 reads the make BUILTIN \$(CXX) — LLVM was built by an" >&2
  echo "             ambient compiler, not the pinned g++." >&2
  exit 1; }
grep -q 'llvm-project' "${BUILDROOT}/cxxwrap.log" || {
  echo "rustc GATE-6: FAIL — no llvm-project translation unit in cxxwrap.log." >&2
  echo "             LLVM did not go through the pinned g++." >&2
  exit 1; }
INTERP="$(readelf -l "${DST}/bin/rustc_binary" 2>/dev/null | grep -o '/[^]]*ld-linux[^]]*' | head -1 || true)"
[ "${INTERP}" = "${LOADER}" ] || {
  echo "rustc GATE-6: FAIL — rustc_binary interpreter = '${INTERP}', expected '${LOADER}'" >&2; exit 1; }
echo "rustc GATE-6: PASS (cc=$(wc -l < "${BUILDROOT}/ccwrap.log" | tr -d ' ') c++=$(wc -l < "${BUILDROOT}/cxxwrap.log" | tr -d ' ') invocations; LLVM via the pinned g++; glibc loader)" >&2

# --- GATE-7: offline re-check after the gates (cargo in GATE-5 is the candidate) ---
if [ -e "${BUILDROOT}/NETWORK-TRIPWIRE" ]; then
  echo "rustc: FATAL a network fetch was attempted during the gate phase:" >&2
  cat "${BUILDROOT}/NETWORK-TRIPWIRE" >&2; exit 1
fi
echo "rustc GATE-7: PASS (network tripwire clean after all gates)" >&2

# --- P8 byte seal ---
# Arms itself once rustc-1.90.0.answers contains a `<sha256>  <path>` line. Cross-run
# byte-identity is not expected: minicargo.mk:294-303 sets no LLVM_APPEND_VC_REV or timestamp
# suppression, and the cargo-driven stages have their own metadata-hash surface.
ANS="${BUILDROOT}/rustc-${VERSION}.answers"
if grep -Eq '^[0-9a-f]{64}  ' "${ANS}"; then
  if ( cd "${OUTPUT_DIR}" && sha256sum -c "${ANS}" ); then
    echo "rustc SEAL: PASS (byte-identical to the pinned answers)" >&2
  else
    echo "rustc SEAL: FAIL (output drifted from rustc-${VERSION}.answers)" >&2
    exit 1
  fi
else
  echo "rustc SEAL: no pins present in rustc-${VERSION}.answers; seal not checked" >&2
fi
