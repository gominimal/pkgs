#!/bin/sh
# ============================================================================================
# build.sh — B5 (gcc-15.2.0-glibc) driver.  REVIEW-READY scaffold 2026-07-03.
# ============================================================================================
# The GLIBC-LINKED twin of R12 (stage0-gcc-15.2.0).  Same PRODUCTION gcc-15.2.0 source the ecosystem
# ships, built BY R12 (the musl-linked gcc-15.2.0 driver) but retargeted onto the from-source
# glibc-2.42 sysroot (B4 = glibc-bedrock-2.42) and emitting GLIBC-LINKED SHARED runtime libs
# (libstdc++.so.6, libgcc_s.so.1, libgomp.so, libatomic.so, libquadmath.so) — the leaves the 368
# downstream packages dynamically link.  Assembled by binutils-2.46-glibc (the matched set).
#
# ── R12(musl) -> B5(glibc) DELTA (line-level) ──────────────────────────────────────────────────
#   1. SR: /usr/lib/musl-bedrock-1.2.5 -> /usr/lib/glibc-bedrock-2.42 (UAPI co-located).
#   2. host wrappers + target flags DROP `-static` (glibc dynamic; interp /lib64/ld-linux-x86-64.so.2).
#   3. DELETE the `sed os/gnu-linux -> os/generic` (musl ctype workaround; glibc WANTS os/gnu-linux).
#   4. DROP --with-native-system-header-dir (produced gcc defaults to glibc /usr/include, prod posture).
#   5. --enable-shared (was --disable-shared): the .so runtime libs.
#   6. DROP --disable-lto + the --disable-lib{gomp,atomic,quadmath,itm,ssp,sanitizer} set; ADD
#      --enable-default-pie --enable-default-ssp --disable-fixincludes.
#   7. ADD the production x86_64 t-linux64 lib64->lib sed (glibc slibdir=/usr/lib parity).
#
# ⚠ DESIGN FORK (host libc): this scaffold builds the C++ host programs (cc1plus/f951) with R12's g++,
#   whose libstdc++.a was built against MUSL, and links them glibc-dynamic -> a musl-libstdc++/glibc
#   mix (the "compiles != correct" zone).  Option A (safer): keep host programs musl-static (R12's
#   wrappers verbatim) and build only the TARGET libs glibc-shared.  See build.ncl banner + readiness.
#   The correctness gate below is the fail-shut backstop either way.
set -ex
VERSION="${MINIMAL_ARG_VERSION:-15.2.0}"
TARBALL="gcc-${VERSION}.tar.xz"
SRC="gcc-${VERSION}"
BUILDROOT="$(pwd)"
PREFIX=/usr
LIBDIR=/usr/lib
TARGET="x86_64-linux-gnu"
GCC_MATH=/usr/lib/gcc-math                 # R8: libgmp/libmpfr/libmpc.a + headers (cc1's bignum middle-end)
SR=/usr/lib/glibc-bedrock-2.42             # B4: from-source glibc-2.42 versioned sysroot (headers + crt + libs + UAPI)
LOADER="$SR/lib/ld-linux-x86-64.so.2"

BUILDER_GCC="$(command -v gcc || true)"
BUILDER_GXX="$(command -v g++ || command -v ${TARGET}-g++ || true)"
[ -n "${BUILDER_GCC}" ] || { echo "B5 infra: builder gcc (R12) not on PATH" >&2; exit 1; }
[ -n "${BUILDER_GXX}" ] || { echo "B5 infra: builder g++ (R12, C++ HOST compiler) not on PATH" >&2; exit 1; }
command -v as >/dev/null 2>&1 || { echo "B5 infra: as (binutils-2.46-glibc) not on PATH" >&2; exit 1; }
[ -f "${GCC_MATH}/lib/libgmp.a" ] || { echo "B5 infra: R8 gmp/mpfr/mpc missing at ${GCC_MATH}" >&2; exit 1; }
[ -e "${SR}/lib/libc.so" ]        || { echo "B5 infra: B4 glibc sysroot missing at ${SR} (libc.so)" >&2; exit 1; }
[ -f "${SR}/lib/crt1.o" ]         || { echo "B5 infra: B4 glibc startfiles missing at ${SR}/lib (crt1.o)" >&2; exit 1; }
[ -f "${SR}/lib/Scrt1.o" ]        || { echo "B5 infra: B4 glibc PIE startfiles missing at ${SR}/lib (Scrt1.o — --enable-default-pie gate link needs it)" >&2; exit 1; }
[ -e "${LOADER}" ]                || { echo "B5 infra: B4 glibc loader missing at ${LOADER}" >&2; exit 1; }
[ -f /usr/lib/libstdc++.a ]       || { echo "B5 infra: R12 libstdc++.a missing at /usr/lib" >&2; exit 1; }

# determinism parity with binutils-2.46-glibc (load-bearing for the B6 empty-diff): drop build-id from host bins.
export LDFLAGS="-Wl,--build-id=none"

# libc.so LINKER-SCRIPT FIX (same as binutils-2.46-glibc): the sealed B4 versioned libc.so baked
# /build/output/... staging paths -> regenerate a corrected script ld finds first (prefix-agnostic).
FIXLIB="${BUILDROOT}/glibc-fixlib"; mkdir -p "${FIXLIB}"
sed -E "s@[^ ()]*/(libc\.so\.6|libc_nonshared\.a|ld-linux-x86-64\.so\.2)@${SR}/lib/\1@g" \
  "${SR}/lib/libc.so" > "${FIXLIB}/libc.so"
grep -q '/build/output' "${FIXLIB}/libc.so" && { echo "B5 infra: libc.so fixup failed" >&2; exit 1; }

# --- unpack (.tar.xz; --no-same-owner: chown-hostile sandbox userns) ---
tar --no-same-owner -xf "${TARBALL}"
cd "${SRC}"

# ============================================================================================
# GLIBC slibdir PARITY — production packages/gcc/build.sh maps the x86_64 m64 multilib osdir lib64->lib
# so the produced gcc searches /usr/lib (glibc-bedrock uses libc_cv_slibdir=/usr/lib).  R12 (musl,
# --disable-multilib) didn't need it; B5 does, for a glibc system with libs in /usr/lib.
# ============================================================================================
case "$(uname -m)" in
  x86_64)  sed -e '/m64=/s/lib64/lib/'      -i.orig gcc/config/i386/t-linux64 ;;
  aarch64) sed -e '/mabi.lp64=/s/lib64/lib/' -i.orig gcc/config/aarch64/t-aarch64-linux ;;
esac

# ============================================================================================
# HOST-TOOLCHAIN WRAPPERS — R12's gcc/g++ retargeted onto the glibc-2.42 sysroot.  DROP `-static`
# (glibc dynamic).  GI = R12-gcc's freestanding headers (stddef/stdarg — language agnostic).
# ============================================================================================
GI="$("${BUILDER_GCC}" -print-file-name=include)"
[ -d "${GI}" ] || { echo "B5 infra: builder-gcc freestanding include dir not found ('${GI}')" >&2; exit 1; }

# R12's INSTALLED libstdc++ headers (version-agnostic via the c++config.h probe).
CXXCFG="$(ls /usr/include/c++/*/${TARGET}/bits/c++config.h 2>/dev/null | head -n1)"
[ -n "${CXXCFG}" ] || { echo "B5 infra: R12 libstdc++ target headers (c++config.h) not found under /usr/include/c++/*/${TARGET}/bits" >&2; exit 1; }
CXX_TGT_DIR="$(cd "$(dirname "${CXXCFG}")/.." && pwd)"   # /usr/include/c++/<ver>/<target>
CXX_BASE_DIR="$(dirname "${CXX_TGT_DIR}")"               # /usr/include/c++/<ver>

# gcc-cc (C host wrapper): -nostdinc drops /usr; add R12-gcc freestanding + glibc C headers.  Glibc-DYNAMIC link.
cat > "${BUILDROOT}/gcc-cc" <<WRAP
#!/bin/sh
INC="-isystem ${GI} -isystem ${SR}/include"
for a in "\$@"; do case "\$a" in -c|-S|-E) exec "${BUILDER_GCC}" -nostdinc \$INC "\$@" ;; esac; done
exec "${BUILDER_GCC}" -nostdinc \$INC -L "${FIXLIB}" -B "${SR}/lib" -L "${SR}/lib" -Wl,--dynamic-linker="${SR}/lib/ld-linux-x86-64.so.2" "\$@"
WRAP
chmod +x "${BUILDROOT}/gcc-cc"
GCCCC="${BUILDROOT}/gcc-cc"

# gcc-cxx (C++ host wrapper) — include_next-SAFE posture (R12's proven ordering): -nostdinc -nostdinc++
# then re-add EXPLICITLY: R12's C++ std hdrs -> gcc freestanding -> glibc C hdrs.  <cstdlib>'s
# include_next <stdlib.h> now resolves to ${SR}/include (glibc).  Glibc-DYNAMIC link (no -static).
# ⚠ FORK: R12's libstdc++.a is MUSL-built; linking it glibc-dynamic is the mixing hazard (see banner).
cat > "${BUILDROOT}/gcc-cxx" <<WRAP
#!/bin/sh
INC="-isystem ${CXX_BASE_DIR} -isystem ${CXX_TGT_DIR} -isystem ${CXX_BASE_DIR}/backward -isystem ${GI} -isystem ${SR}/include"
for a in "\$@"; do case "\$a" in -c|-S|-E) exec "${BUILDER_GXX}" -nostdinc -nostdinc++ \$INC "\$@" ;; esac; done
exec "${BUILDER_GXX}" -nostdinc -nostdinc++ \$INC -L "${FIXLIB}" -B "${SR}/lib" -L "${SR}/lib" -Wl,--dynamic-linker="${SR}/lib/ld-linux-x86-64.so.2" "\$@"
WRAP
chmod +x "${BUILDROOT}/gcc-cxx"
GCCCXX="${BUILDROOT}/gcc-cxx"

# ============================================================================================
# SOURCE seds.
#  (a) unwind headers — DEFENSIVE NO-OP on 15 (siginfo/ucontext types fixed upstream in gcc-8).
#  (b) ★ NO os/generic sed.  R12 mapped os/gnu-linux -> os/generic as a MUSL ctype workaround
#      (musl lacks glibc's _ISupper/_ISalpha constants).  glibc's os/gnu-linux ctype path is CORRECT
#      and WANTED -> we must NOT touch configure.host.  This is the single most important libstdc++ flip.
# ============================================================================================
for f in gcc/config/i386/linux-unwind.h; do
  [ -f "$f" ] && sed -i 's/struct siginfo/siginfo_t/g; s/struct ucontext/ucontext_t/g' "$f"
done

# ============================================================================================
# MODEL-B mtime guard + LOUD regen stubs (ported from R12).  Baseline EVERY file old, bump the SHIPPED
# generated set newest so make never fires an absent bison/flex on a checked-in generated file.
# ============================================================================================
find . -exec touch -d '2001-01-01 00:00:00' {} +
# shellcheck disable=SC2046
touch $(find . \( -name configure -o -name 'config.in' -o -name 'config.h.in' -o -name 'aclocal.m4' \
                  -o -name 'Makefile.in' -o -name '*.info' -o -name '*.gmo' \
                  -o -name 'gengtype-lex.c' -o -name 'gengtype-lex.cc' \
                  -o -name '*.tab.c' -o -name '*.tab.h' \
                  -o -name 'plural.c' -o -name 'fixincl.x' \) -print) 2>/dev/null || true
STUBS="${BUILDROOT}/regen-stubs"; mkdir -p "${STUBS}"
for t in bison yacc flex lex m4 gperf perl autoconf autoheader autom4te aclocal automake autoreconf libtoolize; do
  printf '#!/bin/sh\necho "B5 MODEL-B GUARD: %s invoked ($*) -> a generated file is being regenerated; add it to the touch list." >&2\nexit 1\n' "$t" > "${STUBS}/${t}"
  chmod +x "${STUBS}/${t}"
done
export PATH="${STUBS}:${PATH}"

# ============================================================================================
# src_configure — out-of-tree, TOP-LEVEL.  PRODUCTION packages/gcc/build.sh ABI (glibc-linked SHARED):
#   --enable-languages=c,c++,fortran : production set (libstdc++.so.6 + libgcc_s.so.1 + libgfortran +
#     libgomp/libatomic/libquadmath).  Trim to `c,c++` if fortran/libgfortran walls the cold build.
#   --enable-shared : the .so runtime libs (the whole POINT of B5 vs R12's --disable-shared).
#   --enable-default-pie --enable-default-ssp : production hardening ABI.
#   --disable-fixincludes : production (glibc headers are clean).
#   --disable-bootstrap : single-stage (R12-consistent).  --disable-multilib --disable-nls.
#   --without-isl : Graphite off (no ISL in the closure).
#   --with-gmp/mpfr/mpc=/usr/lib/gcc-math : R8's static bignum middle-end (musl .a; libc-agnostic).
#   NO --with-native-system-header-dir : produced gcc defaults to glibc /usr/include (production).
#   --with-system-zlib OMITTED : no seed-rooted bedrock zlib -> gcc's BUNDLED zlib (ABI-inert; readiness follow-up).
# ============================================================================================
mkdir "${BUILDROOT}/build"
cd "${BUILDROOT}/build"
CC="${GCCCC}" CXX="${GCCCXX}" AR=ar RANLIB=ranlib \
  "../${SRC}/configure" \
    --prefix="${PREFIX}" --libdir="${LIBDIR}" \
    --build="${TARGET}" --host="${TARGET}" --target="${TARGET}" \
    --enable-languages=c,c++,fortran \
    --enable-shared \
    --enable-default-pie --enable-default-ssp \
    --disable-bootstrap --disable-multilib --disable-nls \
    --disable-fixincludes \
    --without-isl \
    --with-gmp="${GCC_MATH}" --with-mpfr="${GCC_MATH}" --with-mpc="${GCC_MATH}" \
    --program-transform-name=

# ============================================================================================
# src_compile / src_install — CPATH/LIBRARY_PATH pin the fresh xgcc's TARGET-lib build to the versioned
# glibc sysroot (deterministic; sidesteps the /usr coin-flip).  -j via nproc (production).
# FT (target flags): DROP -static (glibc dynamic -> shared target libs are buildable + link glibc).
# ============================================================================================
export CPATH="${SR}/include"
export LIBRARY_PATH="${SR}/lib"
FT="-g -O2 -B ${SR}/lib -L ${SR}/lib"
make -j"$(nproc)" MAKEINFO=true CFLAGS_FOR_TARGET="${FT}" CXXFLAGS_FOR_TARGET="${FT}"
make -j"$(nproc)" MAKEINFO=true CFLAGS_FOR_TARGET="${FT}" CXXFLAGS_FOR_TARGET="${FT}" DESTDIR="${OUTPUT_DIR}" install

# ============================================================================================
# CORRECTNESS GATE — B5 is "the first rung that emits libgcc_s.so.1", so it exercises the SHARED /
# cross-DSO surfaces B4 had to DEFER (B4 was --disable-shared).  The freshly-INSTALLED g++ (from
# $OUTPUT_DIR, NOT deployed to /usr) must, glibc-DYNAMIC against the fresh libstdc++.so.6/libgcc_s.so.1:
#   (a) throw an exception ACROSS a DSO boundary (thrower.so throws, main catches) -> cross-DSO EH
#       through libgcc_s.so.1 (the exact check B4 could not run);
#   (b) backtrace(3) returns > 0 frames (glibc + libgcc_s unwinder);
#   (c) long-double / %.17g / %a printf (the R4 fmt_fp silent-corruption class);
#   (d) __thread TLS across two TUs.
# Run via an EXPLICIT loader invocation (no /lib64 symlink dependency) with LD_LIBRARY_PATH pointing at
# the fresh gcc libs + the glibc sysroot.  FAIL-SHUT (gcc is deterministic).
# ============================================================================================
XGXX="${OUTPUT_DIR}/usr/bin/g++"
[ -x "${XGXX}" ] || XGXX="${OUTPUT_DIR}/usr/bin/${TARGET}-g++"
GATE="${BUILDROOT}/b5gate"; rm -rf "${GATE}"; mkdir -p "${GATE}"
CB="${OUTPUT_DIR}/usr/include/c++/${VERSION}"
GIX="$("${XGXX}" -print-file-name=include)"
GXXINC="-nostdinc -nostdinc++ -isystem ${CB} -isystem ${CB}/${TARGET} -isystem ${CB}/backward -isystem ${GIX} -isystem ${SR}/include"
GLNK="-B ${SR}/lib -L ${SR}/lib -L ${OUTPUT_DIR}/usr/lib"
GRUN_LIBS="${OUTPUT_DIR}/usr/lib:${SR}/lib"

# --- shared lib: throws across the DSO boundary ---
cat > "${GATE}/thrower.cpp" <<'EOF'
struct E { int v; };
void do_throw(int x){ throw E{x}; }
EOF
# --- main: catches the cross-DSO throw + backtrace(3) ---
cat > "${GATE}/main.cpp" <<'EOF'
#include <cstdio>
#include <execinfo.h>
struct E { int v; };
void do_throw(int);
int main(){
  int fails = 0;
  try { do_throw(7); }
  catch (const E& e){ if (e.v != 7){ fprintf(stderr, "GATE xdso-eh: v=%d want 7\n", e.v); fails++; } }
  catch (...) { fprintf(stderr, "GATE xdso-eh: wrong type caught\n"); fails++; }
  void* bt[16];
  int n = backtrace(bt, 16);
  if (n <= 0){ fprintf(stderr, "GATE backtrace: n=%d\n", n); fails++; }
  if (fails){ fprintf(stderr, "B5-GATE-CXX: FAIL (%d)\n", fails); return 1; }
  printf("OK\n");
  return 0;
}
EOF
set +e
"${XGXX}" -std=gnu++14 -fPIC -shared ${GXXINC} ${GLNK} "${GATE}/thrower.cpp" -o "${GATE}/libthrower.so" 2>"${GATE}/cxx.err"
src=$?
"${XGXX}" -std=gnu++14 ${GXXINC} ${GLNK} -L "${GATE}" "${GATE}/main.cpp" -lthrower -o "${GATE}/xdso" 2>>"${GATE}/cxx.err"
mrc=$?
COUT="<compile-failed>"
if [ $src -eq 0 ] && [ $mrc -eq 0 ]; then
  COUT="$(LD_LIBRARY_PATH="${GATE}:${GRUN_LIBS}" timeout 30 "${LOADER}" --library-path "${GATE}:${GRUN_LIBS}" "${GATE}/xdso" 2>>"${GATE}/cxx.err")"
fi
set -e
if [ "${COUT}" = "OK" ]; then
  echo "B5-GATE-CXX: PASS (cross-DSO C++ EH via libgcc_s.so.1 + backtrace against fresh glibc)" >&2
else
  echo "B5-GATE-CXX: FAIL (thrower rc=$src main rc=$mrc out='${COUT}'); tail:" >&2; tail -20 "${GATE}/cxx.err" >&2 || true
  exit 1
fi

# --- (c)+(d) float / TLS correctness (C, glibc-dynamic) — the R4 fmt_fp silent-corruption class ---
cat > "${GATE}/tls_b.c" <<'EOF'
__thread int tls_v = 7;
int tls_get(void){ return tls_v; }
EOF
cat > "${GATE}/gate.c" <<'EOF'
#include <stdio.h>
#include <string.h>
extern __thread int tls_v;
extern int tls_get(void);
int main(void){
  char b[64]; int fails = 0;
  long double ld = 1.5L;
  snprintf(b, sizeof b, "%.1Lf", ld);
  if (strcmp(b, "1.5") != 0){ fprintf(stderr, "GATE Lf: '%s'\n", b); fails++; }
  snprintf(b, sizeof b, "%.17g", 1.5 + 2.25);
  if (strcmp(b, "3.75") != 0){ fprintf(stderr, "GATE g: '%s'\n", b); fails++; }
  snprintf(b, sizeof b, "%a", 1.0);
  if (strcmp(b, "0x1p+0") != 0){ fprintf(stderr, "GATE a: '%s'\n", b); fails++; }
  tls_v = 42;
  if (tls_get() != 42){ fprintf(stderr, "GATE tls: %d\n", tls_get()); fails++; }
  if (fails){ fprintf(stderr, "B5-GATE-C: FAIL (%d)\n", fails); return 1; }
  printf("OK\n"); return 0;
}
EOF
XGCC="${OUTPUT_DIR}/usr/bin/gcc"
[ -x "${XGCC}" ] || XGCC="${OUTPUT_DIR}/usr/bin/${TARGET}-gcc"
set +e
"${XGCC}" -nostdinc -isystem "${GIX}" -isystem "${SR}/include" ${GLNK} \
  "${GATE}/gate.c" "${GATE}/tls_b.c" -o "${GATE}/gate" 2>"${GATE}/cc.err"
crc=$?
FOUT="<compile-failed>"
[ $crc -eq 0 ] && FOUT="$(timeout 30 "${LOADER}" --library-path "${GRUN_LIBS}" "${GATE}/gate" 2>>"${GATE}/cc.err")"
set -e
if [ "${FOUT}" = "OK" ]; then
  echo "B5-GATE-C: PASS (float/long-double/TLS correct against fresh glibc)" >&2
else
  echo "B5-GATE-C: FAIL (rc=$crc out='${FOUT}'); tail:" >&2; tail -20 "${GATE}/cc.err" >&2 || true
  exit 1
fi

# ============================================================================================
# BYTE-IDENTITY: NOT sealed at B5 by design (a different compiler than the prebuilt built it -> different
# bytes; readiness risk #3).  The determinism proof is B6 (differential-coreutils).  No `sha256sum -c`
# gate here.  See stage0.answers.
# ============================================================================================
