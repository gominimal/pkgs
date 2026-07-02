#!/bin/sh
# build.sh — R12 (stage0-gcc-15.2.0) driver.  DRAFT 2026-07-02.  Clones the PROVEN R11 (stage0-gcc-10.4.0
# THE PIVOT) recipe + VERSION bump; the copy-forward is probe-validated (below).  R12 is the FIRST
# from-source MODERN PRODUCTION gcc — the exact 15.2.0 minimal's stdenv ships — built BY the R11 pivot
# (gcc-10.4.0), musl-linked (R7), gmp/mpfr/mpc from R8, assembled by binutils-2.41 (R10).  It is the
# modern-gcc gate before B4's glibc-2.42 hop (glibc hard-requires gcc>=12.1; the 10.4 pivot can't build it).
#
# ✅  HOST-LANGUAGE GATE CLEARED (probe 2026-07-02, gcc-15.2.0/gcc/doc/install.texi:225): gcc-15 needs an
#   ISO C++14 host; the R11 pivot gcc-10.4.0 has COMPLETE C++14 + C++17 → clears it with margin.  This is
#   the INVERSE of the fatal 10.5 case (host had only experimental C++11).  A single 10.4->15.2 hop is
#   valid with NO stepping stone.  build.ncl's CC import is the swap-point to gcc-14.3.0 (mirrored) if the
#   5-major jump ever ICEs under --disable-bootstrap.
#
# ── COPY-FORWARD HAZARDS (all probe-CLEARED 2026-07-02; the R11 recipe transfers) ────────────────────
#   1. BUILD-WITH-CXX (gcc is C++-implemented): CC=gcc-cc (R11's gcc), CXX=gcc-cxx (R11's g++ + libstdc++.a).
#   2. gcc-cxx WRAPPER: include_next-SAFE posture (-nostdinc -nostdinc++ + EXPLICIT C++ dirs before musl).
#   3. os/generic ctype sed: STILL fires — probe found `os/gnu-linux` at libstdc++-v3/configure.host:277.
#   4. CFLAGS_FOR_TARGET/CXXFLAGS_FOR_TARGET="-B -L $SR/lib -static": libstdc++ LINK test needs it (musl static).
#   5. --disable optional target libs (libitm/libatomic/libsanitizer/libssp/libgomp/libquadmath): musl-risky.
#   6. Model-B mtime guard: gcc-15's flex output is gengtype-lex.cc (already in the touch-list); NO bison
#      .tab.c in the c/c++ frontend (hand-written recursive descent); flex/bison only for cobol (not built).
#   7. .tar.xz; gmp/mpfr/mpc mins (GMP>=4.3.2/MPFR>=3.1.0/MPC>=0.8.1) probe-cleared vs R8's 6.2.1/4.1.0/1.2.1.
set -ex
VERSION="${MINIMAL_ARG_VERSION:-15.2.0}"   # R12 = PRODUCTION gcc-15.2.0, built by the R11 pivot (gcc-10.4.0)
TARBALL="gcc-${VERSION}.tar.xz"            # FULL gcc (C++), .tar.xz (needs xz in the closure)
SRC="gcc-${VERSION}"
BUILDROOT="$(pwd)"
PREFIX=/usr
LIBDIR=/usr/lib
TARGET="x86_64-linux-gnu"                  # consistency w/ sealed R6→R9; -static makes glibc specs inert
GCC_MATH=/usr/lib/gcc-math                 # R8: libgmp/libmpfr/libmpc.a + headers
SR=/usr/lib/musl-bedrock-1.2.5             # R7: clean musl-1.2.5 sysroot

# The builder toolchain drivers (R9 today; the intermediate rung once/if it exists).  program-transform
# was empty on R9, so unprefixed gcc/g++ exist; fall back to the target-prefixed name if not.
BUILDER_GCC="$(command -v gcc || true)"
BUILDER_GXX="$(command -v g++ || command -v ${TARGET}-g++ || true)"
[ -n "${BUILDER_GCC}" ] || { echo "R11 infra: builder gcc not on PATH" >&2; exit 1; }
[ -n "${BUILDER_GXX}" ] || { echo "R11 infra: builder g++ not on PATH (need a C++ HOST compiler — R9's g++)" >&2; exit 1; }
command -v as >/dev/null 2>&1 || { echo "R11 infra: as (binutils) not on PATH" >&2; exit 1; }
[ -f "${GCC_MATH}/lib/libgmp.a" ] || { echo "R11 infra: R8 gmp/mpfr/mpc missing at ${GCC_MATH}" >&2; exit 1; }
[ -f "${SR}/lib/libc.a" ] || { echo "R11 infra: R7 musl-1.2.5 sysroot missing at ${SR}" >&2; exit 1; }
# ★ R11-SPECIFIC (Q1): the HOST g++ (R9) LINKS R9's libstdc++.a and needs R9's C++ headers.  Both must be
# present in the sandbox — R9 ships them via cxx_libs=usr/lib/*.a + cxx_includes=usr/include/c++/**.  Fail
# LOUD here rather than 200 lines into a cryptic "cstdio: No such file" / "undefined std::__throw_*".
[ -f /usr/lib/libstdc++.a ] || { echo "R11 infra: builder libstdc++.a missing at /usr/lib (R9 must ship it as cxx_libs)" >&2; exit 1; }

# --- unpack (.tar.xz; --no-same-owner: chown-hostile, the R8 wall.  GNU tar autodetects xz via the closure) ---
tar --no-same-owner -xf "${TARBALL}"
cd "${SRC}"

# ============================================================================================
# HOST-TOOLCHAIN WRAPPERS — force R9's gcc/g++ onto R7's clean musl-1.2.5 sysroot (their own baked search
# points at the coin-flip /usr).  GI = R9-gcc's freestanding headers (stddef/stdarg — language agnostic).
# ============================================================================================
GI="$("${BUILDER_GCC}" -print-file-name=include)"
[ -d "${GI}" ] || { echo "R11 infra: builder-gcc freestanding include dir not found ('${GI}')" >&2; exit 1; }

# Discover R9's INSTALLED libstdc++ headers (version-agnostic via the c++config.h probe — keeps the CC/CXX
# swap-point in build.ncl honest: a 4.8.5/9.5.0 intermediate would just resolve a different <ver>).  For a
# from-source native build c++config.h lives at <base>/<ver>/<target>/bits/c++config.h.
CXXCFG="$(ls /usr/include/c++/*/${TARGET}/bits/c++config.h 2>/dev/null | head -n1)"
[ -n "${CXXCFG}" ] || { echo "R11 infra: builder libstdc++ target headers (c++config.h) not found under /usr/include/c++/*/${TARGET}/bits" >&2; exit 1; }
CXX_TGT_DIR="$(cd "$(dirname "${CXXCFG}")/.." && pwd)"   # /usr/include/c++/<ver>/<target>
CXX_BASE_DIR="$(dirname "${CXX_TGT_DIR}")"               # /usr/include/c++/<ver>

# gcc-cc (C host wrapper): -nostdinc drops /usr; add R9-gcc freestanding + musl C headers.  Static musl link.
cat > "${BUILDROOT}/gcc-cc" <<WRAP
#!/bin/sh
INC="-isystem ${GI} -isystem ${SR}/include"
for a in "\$@"; do case "\$a" in -c|-S|-E) exec "${BUILDER_GCC}" -nostdinc \$INC "\$@" ;; esac; done
exec "${BUILDER_GCC}" -nostdinc \$INC -B "${SR}/lib" -L "${SR}/lib" -static "\$@"
WRAP
chmod +x "${BUILDROOT}/gcc-cc"
GCCCC="${BUILDROOT}/gcc-cc"

# gcc-cxx (C++ host wrapper) — include_next-SAFE posture (findings wall #5 SOLVED, not merely "watched").
#   PROBLEM: gcc-10's C++ host source does #include <vector>/<cstdlib>; libstdc++'s <cstdlib> ends with
#   `#include_next <stdlib.h>`, which must reach MUSL's stdlib.h, not glibc's /usr/include.  If we kept
#   the built-in C++ dirs (naive "-nostdinc only") and injected musl via -isystem, the -isystem dir sorts
#   BEFORE the standard C++ dirs (GCC: "-isystem … before the standard system directories") → <cstdlib>
#   is found AFTER musl in the search order → its include_next steps OVER musl → "stdlib.h: No such file".
#   FIX (identical to R9's own smoke-gate posture): -nostdinc -nostdinc++ to drop BOTH built-in chains,
#   then re-add EXPLICITLY in the correct order: C++ std hdrs (R9's) → gcc freestanding → musl C hdrs.  Now
#   <cstdlib> is found in CXX_BASE_DIR and its include_next <stdlib.h> resolves to ${SR}/include (musl).
cat > "${BUILDROOT}/gcc-cxx" <<WRAP
#!/bin/sh
INC="-isystem ${CXX_BASE_DIR} -isystem ${CXX_TGT_DIR} -isystem ${CXX_BASE_DIR}/backward -isystem ${GI} -isystem ${SR}/include"
for a in "\$@"; do case "\$a" in -c|-S|-E) exec "${BUILDER_GXX}" -nostdinc -nostdinc++ \$INC "\$@" ;; esac; done
exec "${BUILDER_GXX}" -nostdinc -nostdinc++ \$INC -B "${SR}/lib" -L "${SR}/lib" -static "\$@"
WRAP
chmod +x "${BUILDROOT}/gcc-cxx"
GCCCXX="${BUILDROOT}/gcc-cxx"

# ============================================================================================
# musl-compat SOURCE seds.
#  (a) unwind headers — DEFENSIVE NO-OP on 10.4.  struct siginfo→siginfo_t / struct ucontext→ucontext_t
#      shipped upstream in gcc-8 (commit 14c2f22, 2017); 10.4 already uses the correct types, so the
#      `[ -f ] && sed` guard simply won't match.  Kept for provenance symmetry with R6/R9; NOT load-bearing.
#  (b) ★ libstdc++ os/generic — LOAD-BEARING (R9 fix (d), TRANSFERS).  We configure the -GNU triplet
#      (x86_64-linux-gnu) while LINKING musl.  libstdc++'s configure.host maps a -gnu (or plain linux*)
#      triplet → config/os/gnu-linux, whose ctype_base.h references glibc-internal _ISupper/_ISalpha/…
#      constants that musl does NOT define → the libstdc++ ctype build fails.  gcc-10's native musl
#      awareness keys on a *-linux-MUSL triplet, which we deliberately DON'T use (R6→R9 consistency) — so
#      it does NOT rescue us here.  os/generic carries self-contained ctype bit constants (portable, musl-
#      safe).  This is the exact sed R9 proved load-bearing on the same -gnu-on-musl posture.
# ============================================================================================
for f in gcc/config/i386/linux-unwind.h; do
  [ -f "$f" ] && sed -i 's/struct siginfo/siginfo_t/g; s/struct ucontext/ucontext_t/g' "$f"
done
sed -i 's|os/gnu-linux|os/generic|g' libstdc++-v3/configure.host

# ============================================================================================
# MODEL-B mtime guard + LOUD regen stubs (ported from R9/R6).  Baseline EVERY file to one old mtime, then
# bump the SHIPPED generated set newest so make never fires an absent bison/flex/autoconf on a checked-in
# generated file.  gcc-10's generated set differs from 4.7.4's — notably gengtype-lex may be .cc (the .c→
# .cc rename landed later, but match both).  gawk/msgfmt are NOT stubbed: options.c is regenerated during
# the build by gawk (in the closure), and --disable-nls + MAKEINFO=true retire gettext/texinfo cleanly.
# The stubs turn any MISS into a LOUD, named failure instead of silently clobbering a shipped file.
# ⚠ A local configure-probe of the extracted tree is advised before the first cloud build.
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
  printf '#!/bin/sh\necho "R11 MODEL-B GUARD: %s invoked ($*) -> a generated file is being regenerated; add it to the touch list." >&2\nexit 1\n' "$t" > "${STUBS}/${t}"
  chmod +x "${STUBS}/${t}"
done
export PATH="${STUBS}:${PATH}"

# ============================================================================================
# src_configure — out-of-tree, TOP-LEVEL.
#   CC=gcc-cc (C), CXX=gcc-cxx (C++, R9's g++ + libstdc++) — build WITH C++ (delta #1); NO
#     --disable-build-with-cxx (gone in gcc-4.8+; gcc-10 is C++-implemented).
#   --disable-bootstrap: single-stage (SAFE on 10.4 — a C++98 host suffices; this is exactly what made
#     10.5 fatal, since its host g++ would compile every .cc directly with no stage2 rescue).
#   --enable-languages=c,c++ : the point of the pivot (cc1 + cc1plus + g++ + static libstdc++).
#   --without-isl : Graphite off (Q2) — no ISL in the closure, no ISL rung.
#   --disable-lto : the lto-plugin is a .so that can't link static musl (bedrock reflex).
#   --disable-libsanitizer/libssp/libgomp/libquadmath/libitm : glibc-coupled optional runtime libs we
#     don't need + that carry Alpine's musl patch surface (delta #5; libmudflap was removed in gcc-4.9).
#   --disable-libstdcxx-pch : skip the big precompiled-header build (OOM-pole reducer; functionally inert).
#   --disable-shared / --disable-multilib / --disable-nls.
#   --with-gmp/mpfr/mpc=/usr/lib/gcc-math : R8's static trio (Q1 — exceeds gcc-10's minimums).
# ============================================================================================
mkdir "${BUILDROOT}/build"
cd "${BUILDROOT}/build"
CC="${GCCCC}" CXX="${GCCCXX}" AR=ar RANLIB=ranlib \
  "../${SRC}/configure" \
    --prefix="${PREFIX}" --libdir="${LIBDIR}" \
    --build="${TARGET}" --host="${TARGET}" --target="${TARGET}" \
    --enable-languages=c,c++ \
    --disable-bootstrap --disable-shared --disable-multilib --disable-nls \
    --disable-lto --without-isl \
    --disable-libsanitizer --disable-libssp --disable-libgomp --disable-libquadmath --disable-libitm --disable-libatomic \
    --disable-libstdcxx-pch \
    --with-gmp="${GCC_MATH}" --with-mpfr="${GCC_MATH}" --with-mpc="${GCC_MATH}" \
    --program-transform-name=

# ============================================================================================
# src_compile / src_install — fixincludes no-op stub (musl headers are clean); CPATH/LIBRARY_PATH so the
# fresh xgcc compiles crtstuff/libgcc against musl-1.2.5, not the coin-flip /usr.  -j1 (OOM pole — cc1plus
# + libstdc++ are bigger than R9).
# ============================================================================================
printf '#!/bin/sh\nexit 0\n' > "${BUILDROOT}/${SRC}/fixincludes/fixinc.sh" 2>/dev/null || true
mkdir -p fixincludes; printf '#!/bin/sh\nexit 0\n' > fixincludes/fixinc.sh; chmod +x fixincludes/fixinc.sh
export CPATH="${SR}/include"
export LIBRARY_PATH="${SR}/lib"
# ★ LOAD-BEARING (R9 fix (c), TRANSFERS): the fresh xgcc builds the TARGET libs (libgcc, libstdc++).
# libstdc++'s configure runs a LINK test; musl is STATIC-ONLY, so without -static + musl crt on the
# startfile path the executable link fails → autoconf sets GCC_NO_EXECUTABLES → "Link tests are not
# allowed" abort.  -B/-L $SR/lib put musl crt1/crti/crtn + libc.a on the search; -static forces the static
# link.  CPATH/LIBRARY_PATH alone do NOT add -static → necessary-but-insufficient; the -static in FT is the
# real fix.  -g -O2 keeps the default target opt level.
FT="-g -O2 -B ${SR}/lib -L ${SR}/lib -static"
make -j1 STMP_FIXINC= MAKEINFO=true CFLAGS_FOR_TARGET="${FT}" CXXFLAGS_FOR_TARGET="${FT}"
make -j1 STMP_FIXINC= MAKEINFO=true CFLAGS_FOR_TARGET="${FT}" CXXFLAGS_FOR_TARGET="${FT}" DESTDIR="${OUTPUT_DIR}" install

# ============================================================================================
# smoke gate — the built g++ must compile+run a C++14 program exercising libstdc++ (std::vector + a lambda
# + std::accumulate) → proves cc1plus AND the static libstdc++.a work.  Invoke the INSTALLED g++ from
# $OUTPUT_DIR (not deployed to /usr) with R9's proven gate posture: -nostdinc -nostdinc++ + EXPLICIT 10.4
# C++ headers + its OWN gcc-internal include, THEN musl.  (Mirrors the CXX-wrapper ordering so <cstdlib>'s
# include_next reaches musl's stdlib.h.)  FAIL-SHUT (gcc is deterministic).
# ============================================================================================
XGXX="${OUTPUT_DIR}/usr/bin/g++"
[ -x "${XGXX}" ] || XGXX="${OUTPUT_DIR}/usr/bin/${TARGET}-g++"
GATE="${BUILDROOT}/cxxgate"; rm -rf "${GATE}"; mkdir -p "${GATE}"
cat > "${GATE}/t.cpp" <<'CXXGATE'
#include <vector>
#include <numeric>
#include <cstdio>
int main(){ std::vector<int> v{1,2,3,4}; auto s = [&]{ return std::accumulate(v.begin(), v.end(), 0); }(); printf("%d\n", s); return 0; }
CXXGATE
CB="${OUTPUT_DIR}/usr/include/c++/${VERSION}"
GI10="$("${XGXX}" -print-file-name=include)"
set +e
"${XGXX}" -std=gnu++14 -nostdinc -nostdinc++ \
  -isystem "${CB}" -isystem "${CB}/${TARGET}" -isystem "${CB}/backward" \
  -isystem "${GI10}" -isystem "${SR}/include" \
  -B "${SR}/lib" -L "${SR}/lib" -L "${OUTPUT_DIR}/usr/lib" -static \
  "${GATE}/t.cpp" -o "${GATE}/t" 2>"${GATE}/err"
grc=$?
OUT="<compile-failed>"; [ ${grc} -eq 0 ] && OUT="$(timeout 20 "${GATE}/t")"
set -e
if [ "${OUT}" = "10" ]; then
  echo "R12-CXX-GATE: PASS (g++ compiled+ran C++14 + static libstdc++; got '${OUT}')" >&2
else
  echo "R12-CXX-GATE: FAIL (rc=${grc} got '${OUT}', want '10'); tail:" >&2; tail -12 "${GATE}/err" >&2 || true
  exit 1
fi

# ============================================================================================
# BYTE-IDENTITY SEAL — record-at-pin-time (gcc is deterministic → byte-identity is a REAL invariant).
# stage0.answers ships UNPINNED for the capture build; capture cc1/cc1plus/xgcc/xg++/libgcc.a/
# libstdc++.a shas, pin them, then re-enable the `sha256sum -c` gate.
# ============================================================================================
# cd "${OUTPUT_DIR}" && sha256sum -c "${BUILDROOT}/stage0.answers"
