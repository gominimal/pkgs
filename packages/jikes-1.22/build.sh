#!/bin/sh
# ============================================================================================
# build.sh — jikes-1.22: the ROOT of the JVM ladder (minimermetic#89).
#
#   IS:     /usr/lib/jikes-1.22 — IBM's Java compiler, C++ only, built by the seed-rooted B5 gcc
#           against the B4 glibc sysroot. Every JDK's javac is Java; this is the one that is not.
#   IS NOT: a JVM, and it cannot compile a real program alone — it needs a class library on its
#           -bootclasspath (GNU Classpath 0.93, the next rung) and a VM to run the output (jamvm).
#
# Chain: hex0 -> ... -> gcc-15.2.0-glibc (B5) -> THIS.
#
# ── LESSONS CARRIED FROM go-1.4 / go-1.17.13 (do not regress) ───────────────────────────────
#  1. NO findutils in the sandbox — only declared build_deps exist. Assert layouts, don't discover.
#  2. build.sh must be mode 755. 3. Wipe $OUTPUT_DIR first (res-server persists /build).
#  4. Link every binary against the B4 loader (explicit --dynamic-linker + rpath), the way go-1.4 does.
# ── LESSONS FROM THE LAB RUN (jvm-root-probe.sh, 2026-09-11) ────────────────────────────────
#  jikes 1.22 (2005) compiles cleanly with gcc 12 as plain C++; no patches were needed. It was the
#  only rung of the whole ladder that "just built".
# ============================================================================================
set -ex

# STALE-STATE GUARD: start from an EMPTY output (pure coreutils; no findutils in the sandbox).
if [ -n "$OUTPUT_DIR" ] && [ -d "$OUTPUT_DIR" ]; then
  for _e in "$OUTPUT_DIR"/* "$OUTPUT_DIR"/.[!.]* "$OUTPUT_DIR"/..?*; do
    if [ -e "$_e" ] || [ -L "$_e" ]; then rm -r "$_e"; fi
  done
fi
mkdir -p "$OUTPUT_DIR"
VERSION="${MINIMAL_ARG_VERSION:-1.22}"
SRC_TARBALL="jikes-${VERSION}.tar.bz2"
SRC_SHA=0cb02c763bc441349f6d38cacd52adf762302cce3a08e269f1f75f726e6e14e3
BUILDROOT="$(pwd)"
PREFIX="/usr/lib/jikes-${VERSION}"
GCC_VERSION=15.2.0
SR=/usr/lib/glibc-bedrock-2.42     # B4 versioned sysroot: headers + crt + libs
LOADER="${SR}/lib/ld-linux-x86-64.so.2"

# ============================================================================================
# P0 — PRECONDITIONS: the seed-rooted B5 gcc AND g++ (jikes is C++), binutils, the B4 sysroot.
# ============================================================================================
BGCC="$(command -v gcc || true)"; BGXX="$(command -v g++ || true)"
if [ -z "${BGCC}" ] || [ -z "${BGXX}" ]; then echo "jikes infra: B5 gcc/g++ not on PATH" >&2; exit 1; fi
for t in as ld ar ranlib make sed grep tar bzip2 bash sha256sum cp mkdir; do
  command -v "$t" >/dev/null 2>&1 || { echo "jikes infra: '$t' not on PATH" >&2; exit 1; }
done
GCCVER="$("${BGCC}" -dumpversion 2>/dev/null || echo unknown)"
[ "${GCCVER}" = "${GCC_VERSION}" ] || { echo "jikes infra: gcc -dumpversion='${GCCVER}', expected '${GCC_VERSION}' (B5)" >&2; exit 1; }
[ -e "${SR}/lib/libc.so" ] || { echo "jikes infra: B4 sysroot missing at ${SR}" >&2; exit 1; }
[ -e "${LOADER}" ]         || { echo "jikes infra: B4 loader missing at ${LOADER}" >&2; exit 1; }
[ -e "${SRC_TARBALL}" ]    || { echo "jikes infra: source ${SRC_TARBALL} absent" >&2; exit 1; }
echo "${SRC_SHA}  ${SRC_TARBALL}" | sha256sum -c - || { echo "jikes infra: source sha mismatch — refusing to build unpinned" >&2; exit 1; }

# ============================================================================================
# P1 — SYSROOT HARNESS (go-1.4's proven flag set + the B4 libc.so linker-script fixup).
# ============================================================================================
FIXLIB="${BUILDROOT}/glibc-fixlib"; mkdir -p "${FIXLIB}"
sed -E "s@[^ ()]*/(libc\.so\.6|libc_nonshared\.a|ld-linux-x86-64\.so\.2)@${SR}/lib/\1@g" "${SR}/lib/libc.so" > "${FIXLIB}/libc.so"
if grep -q '/build/output' "${FIXLIB}/libc.so"; then echo "jikes infra: libc.so linker-script fixup failed" >&2; exit 1; fi
LNK="-L${FIXLIB} -B${SR}/lib -L${SR}/lib -L/usr/lib -Wl,--dynamic-linker=${LOADER} -Wl,-rpath,${SR}/lib:/usr/lib -Wl,--build-id=none"
# C++ keeps g++'s OWN libstdc++ headers (no -nostdinc); the libc headers come from the B4 sysroot.
INC="-isystem ${SR}/include"
cat > "${BUILDROOT}/cc-wrap" <<WRAP
#!/bin/sh
for a in "\$@"; do case "\$a" in -c|-S|-E) exec "${BGCC}" ${INC} "\$@" ;; esac; done
exec "${BGCC}" ${INC} ${LNK} "\$@"
WRAP
cat > "${BUILDROOT}/cxx-wrap" <<WRAP
#!/bin/sh
for a in "\$@"; do case "\$a" in -c|-S|-E) exec "${BGXX}" ${INC} "\$@" ;; esac; done
exec "${BGXX}" ${INC} ${LNK} "\$@"
WRAP
chmod +x "${BUILDROOT}/cc-wrap" "${BUILDROOT}/cxx-wrap"

# ============================================================================================
# P2 — BUILD. Plain autotools. The archive is sha-pinned: it unpacks to ./jikes-1.22 (assert, don't find).
# ============================================================================================
tar --no-same-owner -xjf "${SRC_TARBALL}"
if [ ! -x "jikes-${VERSION}/configure" ]; then echo "jikes infra: expected jikes-${VERSION}/configure after untar" >&2; ls -la >&2; exit 1; fi
cd "jikes-${VERSION}"
CC="${BUILDROOT}/cc-wrap" CXX="${BUILDROOT}/cxx-wrap" CFLAGS="-O2" CXXFLAGS="-O2" \
  ./configure --prefix="${PREFIX}" --disable-dependency-tracking
make -j"$(nproc 2>/dev/null || echo 4)"
make install DESTDIR="${OUTPUT_DIR}"
cd "${BUILDROOT}"

# ============================================================================================
# P3 — GATE. The binary runs in-sandbox on the B4 loader and reports its version.
# ============================================================================================
J="${OUTPUT_DIR}${PREFIX}/bin/jikes"
[ -x "${J}" ] || { echo "jikes: FATAL bin/jikes missing after install" >&2; exit 1; }
"${J}" --version 2>&1 | grep -q 'Jikes Compiler' || { echo "jikes: FATAL --version did not identify the compiler" >&2; "${J}" --version >&2 || true; exit 1; }
mkdir -p "${OUTPUT_DIR}/usr/share/jikes-${VERSION}"
{
  echo "package:     jikes-${VERSION} (JVM ladder rung 1 — the C++ Java compiler)"
  echo "source:      ${SRC_TARBALL} sha256 ${SRC_SHA}"
  echo "compiler:    ${BGXX} ($("${BGXX}" -dumpversion), B5 seed-rooted)"
  echo "sysroot:     ${SR} (glibc-bedrock-2.42, B4); loader ${LOADER}"
  echo "prefix:      ${PREFIX}"
  echo "version:     $("${J}" --version 2>&1 | head -1)"
} > "${OUTPUT_DIR}/usr/share/jikes-${VERSION}/BUILDINFO"
echo "jikes-${VERSION}: built and gated" >&2
