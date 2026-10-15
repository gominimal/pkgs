#!/bin/sh
# stage0-gcc-4.7.4: builds gcc 4.7.4 (C and C++: cc1, cc1plus, g++, static libstdc++) from
# gcc-4.7.4.tar.bz2 with stage0-gcc-4.0.4 as CC, linked statically against the musl-1.2.5 sysroot,
# gmp/mpfr/mpc from /usr/lib/gcc-math, as/ld from stage0-binutils-2.30. Installed under /usr into
# $OUTPUT_DIR. The tarball ships every generated file; nothing is regenerated.
# phases: preconditions, unpack, CC wrapper, source seds, mtime guard, configure, build, install, C++ smoke gate
set -ex
VERSION="${MINIMAL_ARG_VERSION:-4.7.4}"
TARBALL="gcc-${VERSION}.tar.bz2"          # full gcc tarball (C++), not gcc-core
SRC="gcc-${VERSION}"
BUILDROOT="$(pwd)"
PREFIX=/usr
LIBDIR=/usr/lib
TARGET="x86_64-linux-gnu"
GCC_MATH=/usr/lib/gcc-math                 # libgmp/libmpfr/libmpc.a + headers
SR=/usr/lib/musl-bedrock-1.2.5             # musl-1.2.5 sysroot

command -v gcc >/dev/null 2>&1 || { echo "gcc-4.7.4: gcc (gcc-4.0.4) not on PATH" >&2; exit 1; }
command -v as  >/dev/null 2>&1 || { echo "gcc-4.7.4: as (binutils-2.30) not on PATH" >&2; exit 1; }
[ -f "${GCC_MATH}/lib/libgmp.a" ] || { echo "gcc-4.7.4: gmp/mpfr/mpc missing at ${GCC_MATH}" >&2; exit 1; }
[ -f "${SR}/lib/libc.a" ] || { echo "gcc-4.7.4: musl-1.2.5 sysroot missing at ${SR}" >&2; exit 1; }

# --- unpack (--no-same-owner: the sandbox user namespace cannot chown to the archived uid) ---
tar --no-same-owner -xf "${TARBALL}"
cd "${SRC}"

# --- CC wrapper: gcc-4.0.4 onto the musl-1.2.5 sysroot ---
# -nostdinc with the gcc freestanding headers plus the sysroot headers on compile; -B/-L the sysroot
# and -static on link, so nothing is taken from the merged /usr.
GI="$(gcc -print-file-name=include)"
cat > "${BUILDROOT}/gcc-cc" <<WRAP
#!/bin/sh
GI="${GI}"; SR="${SR}"
for a in "\$@"; do case "\$a" in -c|-S|-E) exec /usr/bin/gcc -nostdinc -isystem "\$GI" -isystem "\$SR/include" "\$@" ;; esac; done
exec /usr/bin/gcc -nostdinc -isystem "\$GI" -isystem "\$SR/include" -B "\$SR/lib" -L "\$SR/lib" -static "\$@"
WRAP
chmod +x "${BUILDROOT}/gcc-cc"
GCCCC="${BUILDROOT}/gcc-cc"

# --- musl source seds ---
# struct siginfo/ucontext -> siginfo_t/ucontext_t in the unwind header (4.7.4 predates musl).
for f in gcc/config/i386/linux-unwind.h; do
  [ -f "$f" ] && { sed -i 's/struct siginfo/siginfo_t/g; s/struct ucontext/ucontext_t/g' "$f"; }
done
# libstdc++'s os/gnu-linux ctype_base.h uses glibc-internal _ISalpha/_ISdigit constants musl does
# not define; force the portable os/generic config (4.7 has no musl config for the -gnu triplet).
sed -i 's|os/gnu-linux|os/generic|g' libstdc++-v3/configure.host

# --- mtime guard + regeneration-tool stubs ---
# The tarball ships every generated file; there is no bison/flex/autoconf here. Make each generated
# file newer than its source so make never regenerates it, and stub the tools so a missed file fails
# by name.
find . -exec touch -d '2001-01-01 00:00:00' {} +
# shellcheck disable=SC2046
touch $(find . \( -name configure -o -name 'config.in' -o -name 'config.h.in' -o -name 'aclocal.m4' \
                  -o -name 'Makefile.in' -o -name '*.info' -o -name '*.gmo' \
                  -o -name 'gengtype-lex.c' -o -name '*-parse.c' -o -name '*.tab.c' -o -name '*.tab.h' \) -print) 2>/dev/null || true
STUBS="${BUILDROOT}/regen-stubs"; mkdir -p "${STUBS}"
for t in bison yacc flex lex m4 gperf perl autoconf autoheader autom4te aclocal automake autoreconf libtoolize; do
  printf '#!/bin/sh\necho "gcc-4.7.4 MODEL-B GUARD: %s invoked ($*) -> a generated file is being regenerated; add it to the touch list." >&2\nexit 1\n' "$t" > "${STUBS}/${t}"
  chmod +x "${STUBS}/${t}"
done
export PATH="${STUBS}:${PATH}"

# --- configure: out of tree, top level ---
#   --disable-bootstrap: single stage.
#   --disable-libsanitizer/libssp: glibc-coupled runtime libs that break on musl.
mkdir "${BUILDROOT}/build"
cd "${BUILDROOT}/build"
# gcc-4.0.4 is C only, so no host C++ preprocessor check can pass. --disable-build-with-cxx builds
# cc1plus with the C host compiler (4.7's sources are still C). Do not set CXX: a C-only CXX makes
# the gcc subdir's /lib/cpp check fail.
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

# --- build + install ---
# No-op fixincludes stub: musl headers need no fixing; the gcc subdir's stmp-fixinc rule wants
# ../fixincludes/fixinc.sh relative to the top-level build dir (the cwd here).
mkdir -p fixincludes; printf '#!/bin/sh\nexit 0\n' > fixincludes/fixinc.sh; chmod +x fixincludes/fixinc.sh
# xgcc builds crtstuff/libgcc with its own baked search path; CPATH/LIBRARY_PATH point it at musl.
export CPATH="${SR}/include"
export LIBRARY_PATH="${SR}/lib"
# Target flags for the fresh xgcc: libstdc++'s configure runs a link test, and without musl's crt on
# the startfile path plus -static (musl is static-only) it sets GCC_NO_EXECUTABLES and aborts.
# -g -O2 keeps the default target optimisation. -j1: cc1plus is the peak-memory step.
FT="-g -O2 -B ${SR}/lib -L ${SR}/lib -static"
make -j1 STMP_FIXINC= MAKEINFO=true CFLAGS_FOR_TARGET="${FT}" CXXFLAGS_FOR_TARGET="${FT}"
make -j1 STMP_FIXINC= MAKEINFO=true CFLAGS_FOR_TARGET="${FT}" CXXFLAGS_FOR_TARGET="${FT}" DESTDIR="${OUTPUT_DIR}" install

# --- smoke gate: the installed g++ must compile and run a C++ program ---
XGXX="${OUTPUT_DIR}/usr/bin/g++"
[ -x "${XGXX}" ] || XGXX="${OUTPUT_DIR}/usr/bin/${TARGET}-g++"
GATE="${BUILDROOT}/cxxgate"; rm -rf "${GATE}"; mkdir -p "${GATE}"
printf '#include <cstdio>\nint main(){ int a[3]={1,2,3}; int s=0; for(int x:a) s+=x; printf("%%d\\n", s); return 0; }\n' > "${GATE}/t.cpp"
set +e
# g++ lives in $OUTPUT_DIR, so its own C++ headers are wired explicitly; -nostdinc/-nostdinc++ keep
# the merged /usr out and musl supplies the C headers and crt.
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
  echo "CXX-GATE: PASS (g++ compiled+ran C++; got '${OUT}')" >&2
else
  echo "CXX-GATE: FAIL (rc=${grc} got '${OUT}', want '6'); tail:" >&2; tail -5 "${GATE}/err" >&2 || true
  exit 1
fi
