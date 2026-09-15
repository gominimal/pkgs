#!/bin/sh
# build.sh — R9 (stage0-gcc-4.7.4) driver.  The FIRST C++ compiler in the bedrock climb (cc1plus/g++).
# FIRST-CUT (2026-07-01): adapts R6 stage0-gcc-4.0.4/build.sh (the proven gcc pattern) to gcc-4.7.4 built
# BY gcc-4.0.4.  Expect iteration (R6 took 7 walls) — this is the highest-risk upper rung (U2/U3).
#
# CC = gcc-4.0.4 via the gcc-cc WRAPPER (libc-using, onto R7's /usr/lib/musl-bedrock-1.2.5).  MATH = R8's
# /usr/lib/gcc-math (--with-gmp/mpfr/mpc).  as/ld/ar/ranlib = binutils-2.30 (R5).  fixincludes no-op stub
# (the permanent gcc-rung pattern).  CPATH/LIBRARY_PATH point the BUILT xgcc's crtstuff/libgcc at musl.
#
# ⚠ UNCERTAIN (iterate against the cloud): (a) the musl-compat seds — 4.7.4 predates musl; known needs are
# struct siginfo->siginfo_t + struct ucontext->ucontext_t in the linux-unwind headers, maybe more;
# (b) the Model-B mtime-guard file list (4.7.4's generated set differs from 4.0.4 — no c-parse.c); the
# regen stubs fail LOUD to name any miss; (c) config.sub swap / cache-var env (per ladder) may be needed.
set -ex
VERSION="${MINIMAL_ARG_VERSION:-4.7.4}"
TARBALL="gcc-${VERSION}.tar.bz2"          # FULL gcc (C++), not gcc-core
SRC="gcc-${VERSION}"
BUILDROOT="$(pwd)"
PREFIX=/usr
LIBDIR=/usr/lib
TARGET="x86_64-linux-gnu"
GCC_MATH=/usr/lib/gcc-math                 # R8: libgmp/libmpfr/libmpc.a + headers
SR=/usr/lib/musl-bedrock-1.2.5             # R7: clean musl sysroot

command -v gcc >/dev/null 2>&1 || { echo "R9 infra: gcc (R6) not on PATH" >&2; exit 1; }
command -v as  >/dev/null 2>&1 || { echo "R9 infra: as (R5 binutils) not on PATH" >&2; exit 1; }
[ -f "${GCC_MATH}/lib/libgmp.a" ] || { echo "R9 infra: R8 gmp/mpfr/mpc missing at ${GCC_MATH}" >&2; exit 1; }
[ -f "${SR}/lib/libc.a" ] || { echo "R9 infra: R7 musl-1.2.5 sysroot missing at ${SR}" >&2; exit 1; }

# --- unpack (.tar.bz2; --no-same-owner: chown-hostile, the R8 wall) ---
tar --no-same-owner -xf "${TARBALL}"
cd "${SRC}"

# ============================================================================================
# gcc-cc WRAPPER (libc-using variant, ported from R8) — gcc-4.0.4 onto the clean musl-1.2.5 sysroot.
# ============================================================================================
GI="$(gcc -print-file-name=include)"
cat > "${BUILDROOT}/gcc-cc" <<WRAP
#!/bin/sh
GI="${GI}"; SR="${SR}"
for a in "\$@"; do case "\$a" in -c|-S|-E) exec /usr/bin/gcc -nostdinc -isystem "\$GI" -isystem "\$SR/include" "\$@" ;; esac; done
exec /usr/bin/gcc -nostdinc -isystem "\$GI" -isystem "\$SR/include" -B "\$SR/lib" -L "\$SR/lib" -static "\$@"
WRAP
chmod +x "${BUILDROOT}/gcc-cc"
GCCCC="${BUILDROOT}/gcc-cc"

# ============================================================================================
# musl-compat SOURCE seds (UNCERTAIN — 4.7.4 predates musl; start with the known unwind-header fixes,
# add more as the cloud reveals them; record in docs/bedrock-patch-provenance.md).
# ============================================================================================
for f in gcc/config/i386/linux-unwind.h; do
  [ -f "$f" ] && { sed -i 's/struct siginfo/siginfo_t/g; s/struct ucontext/ucontext_t/g' "$f"; }
done
# musl: gcc-4.7's libstdc++ config/os/gnu-linux/ctype_base.h uses glibc-internal _ISalpha/_ISdigit/... enum
# constants musl does NOT define. Force the PORTABLE os/generic ctype config for our Linux host (4.7 predates
# musl awareness; a *-linux-musl triplet would want a musl config that doesn't exist in 4.7).
sed -i 's|os/gnu-linux|os/generic|g' libstdc++-v3/configure.host

# ============================================================================================
# MODEL-B mtime guard + regen-tool stubs (ported from R6; the guard file list is BROAD since 4.7.4's
# generated set differs — the stubs fail LOUD to name any file the guard missed).
# ============================================================================================
find . -exec touch -d '2001-01-01 00:00:00' {} +
# shellcheck disable=SC2046
touch $(find . \( -name configure -o -name 'config.in' -o -name 'config.h.in' -o -name 'aclocal.m4' \
                  -o -name 'Makefile.in' -o -name '*.info' -o -name '*.gmo' \
                  -o -name 'gengtype-lex.c' -o -name '*-parse.c' -o -name '*.tab.c' -o -name '*.tab.h' \) -print) 2>/dev/null || true
STUBS="${BUILDROOT}/regen-stubs"; mkdir -p "${STUBS}"
for t in bison yacc flex lex m4 gperf perl autoconf autoheader autom4te aclocal automake autoreconf libtoolize; do
  printf '#!/bin/sh\necho "R9 MODEL-B GUARD: %s invoked ($*) -> a generated file is being regenerated; add it to the touch list." >&2\nexit 1\n' "$t" > "${STUBS}/${t}"
  chmod +x "${STUBS}/${t}"
done
export PATH="${STUBS}:${PATH}"

# ============================================================================================
# src_configure — out-of-tree, TOP-LEVEL (gcc-4.7.4's configure drives libiberty/libcpp/gcc subdirs).
#   --disable-bootstrap: single-stage (no 3-stage self-rebuild — we're seeding, not self-hosting yet).
#   --disable-libsanitizer/libssp: glibc-coupled runtime libs we don't need + that break on musl.
#   --enable-languages=c,c++ : the point of this rung (cc1plus/g++).
# ============================================================================================
mkdir "${BUILDROOT}/build"
cd "${BUILDROOT}/build"
# gcc-4.0.4 (R6) is C-ONLY (no cc1plus) and no C++ headers exist yet (R9 BUILDS the first C++ toolchain),
# so a host C++ preprocessor sanity check cannot pass. Build 4.7.4 WITH C (--disable-build-with-cxx) — cc1plus
# in 4.7 is still C-compilable, so the C host compiles the C++ frontend and the RESULT is a C++ compiler.
# Do NOT set CXX: a C-only gcc-cc as CXX makes the gcc-subdir C++ preprocessor check fail on /lib/cpp.
CC="${GCCCC}" AR=ar RANLIB=ranlib \
  "../${SRC}/configure" \
    --prefix="${PREFIX}" --libdir="${LIBDIR}" \
    --build="${TARGET}" --host="${TARGET}" --target="${TARGET}" \
    --enable-languages=c,c++ \
    --disable-build-with-cxx \
    --disable-bootstrap --disable-shared --disable-multilib --disable-nls \
    --disable-lto \
    --disable-libmudflap --disable-libitm --disable-libsanitizer --disable-libssp --disable-libgomp --disable-libquadmath \
    --with-gmp="${GCC_MATH}" --with-mpfr="${GCC_MATH}" --with-mpc="${GCC_MATH}" \
    --program-transform-name=

# ============================================================================================
# src_compile / src_install — fixincludes no-op stub (gcc-rung pattern); CPATH/LIBRARY_PATH so the built
# xgcc compiles crtstuff/libgcc against musl-1.2.5, not the coin-flip /usr.  -j1 (OOM pole — cc1plus).
# ============================================================================================
# fixincludes no-op stub (musl headers are clean; the gcc subdir's stmp-fixinc wants ../fixincludes/fixinc.sh
# == build/fixincludes/fixinc.sh; CWD here is the top-level build dir):
mkdir -p fixincludes; printf '#!/bin/sh\nexit 0\n' > fixincludes/fixinc.sh; chmod +x fixincludes/fixinc.sh
export CPATH="${SR}/include"
export LIBRARY_PATH="${SR}/lib"
# CFLAGS_FOR_TARGET / CXXFLAGS_FOR_TARGET — the fresh xgcc builds the TARGET libs (libgcc, libstdc++).
# libstdc++'s configure runs a LINK test; without musl's crt on xgcc's startfile path it can't link an
# executable -> autoconf sets GCC_NO_EXECUTABLES -> "Link tests are not allowed" abort. -B $SR/lib puts
# musl crt1/crti/crtn on the startfile search, -L $SR/lib + implicit -lc resolves musl libc.a, -static
# (musl here is static-only). Headers come via CPATH; -g -O2 keeps the default target opt level.
FT="-g -O2 -B ${SR}/lib -L ${SR}/lib -static"
make -j1 STMP_FIXINC= MAKEINFO=true CFLAGS_FOR_TARGET="${FT}" CXXFLAGS_FOR_TARGET="${FT}"
make -j1 STMP_FIXINC= MAKEINFO=true CFLAGS_FOR_TARGET="${FT}" CXXFLAGS_FOR_TARGET="${FT}" DESTDIR="${OUTPUT_DIR}" install

# ============================================================================================
# smoke gate — the built g++ must compile+run a trivial C++ program (proves cc1plus works).  Uses the
# just-installed gcc-4.7.4 against the musl-1.2.5 sysroot.  FAIL-SHUT (gcc is deterministic).
# ============================================================================================
XGXX="${OUTPUT_DIR}/usr/bin/g++"
[ -x "${XGXX}" ] || XGXX="${OUTPUT_DIR}/usr/bin/${TARGET}-g++"
GATE="${BUILDROOT}/cxxgate"; rm -rf "${GATE}"; mkdir -p "${GATE}"
printf '#include <cstdio>\nint main(){ int a[3]={1,2,3}; int s=0; for(int x:a) s+=x; printf("%%d\\n", s); return 0; }\n' > "${GATE}/t.cpp"
set +e
# g++ lives in $OUTPUT_DIR (not deployed to /usr), so wire its OWN installed C++ headers explicitly. The old
# -nostdinc + gcc-4.0.4's $GI killed g++'s C++ header search -> "cstdio: No such file". -nostdinc/-nostdinc++
# keep the coin-flip /usr out; musl supplies the C headers + crt/libc.
CB="${OUTPUT_DIR}/usr/include/c++/${VERSION}"
GI7="$(${XGXX} -print-file-name=include)"
"${XGXX}" -nostdinc -nostdinc++ \
  -isystem "${CB}" -isystem "${CB}/${TARGET}" -isystem "${CB}/backward" \
  -isystem "${GI7}" -isystem "${SR}/include" \
  -B "${SR}/lib" -L "${SR}/lib" -static -std=c++11 \
  "${GATE}/t.cpp" -o "${GATE}/t" 2>"${GATE}/err"
grc=$?
OUT="<compile-failed>"; [ ${grc} -eq 0 ] && OUT="$(timeout 15 "${GATE}/t")"
set -e
if [ "${OUT}" = "6" ]; then
  echo "R9-CXX-GATE: PASS (g++ compiled+ran C++; got '${OUT}')" >&2
else
  echo "R9-CXX-GATE: FAIL (rc=${grc} got '${OUT}', want '6'); tail:" >&2; tail -5 "${GATE}/err" >&2 || true
  exit 1
fi
