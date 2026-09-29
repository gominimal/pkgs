#!/bin/sh
# stage0-gcc-10.4.0: builds gcc 10.4.0 (C and C++: cc1, cc1plus, g++, static libstdc++) from
# gcc-10.4.0.tar.xz with stage0-gcc-4.7.4's gcc/g++ as CC/CXX, linked statically
# against the musl-1.2.5 sysroot, gmp/mpfr/mpc from /usr/lib/gcc-math, as/ld from stage0-binutils-2.41.
# Installed under /usr into $OUTPUT_DIR. VERSION and build.ncl's CC import are the only per-version values.
# gcc-10.4.0 is the last gcc a C++98 host compiler can build; 10.5 requires C++11, which gcc-4.7.4 lacks.
# phases: preconditions, unpack, host wrappers, source seds, mtime guard, configure, build, install, C++ smoke gate, pin gate
set -ex
VERSION="${MINIMAL_ARG_VERSION:-10.4.0}"
TARBALL="gcc-${VERSION}.tar.xz"            # full gcc tarball (C++)
SRC="gcc-${VERSION}"
BUILDROOT="$(pwd)"
PREFIX=/usr
LIBDIR=/usr/lib
TARGET="x86_64-linux-gnu"                  # build=host=target; -static keeps the glibc specs inert
GCC_MATH=/usr/lib/gcc-math                 # libgmp/libmpfr/libmpc.a + headers
SR=/usr/lib/musl-bedrock-1.2.5             # musl-1.2.5 sysroot

# Host compiler drivers. program-transform-name was empty when the host gcc was built, so unprefixed
# gcc/g++ exist; fall back to the target-prefixed name.
BUILDER_GCC="$(command -v gcc || true)"
BUILDER_GXX="$(command -v g++ || command -v ${TARGET}-g++ || true)"
[ -n "${BUILDER_GCC}" ] || { echo "gcc-10.4.0: builder gcc not on PATH" >&2; exit 1; }
[ -n "${BUILDER_GXX}" ] || { echo "gcc-10.4.0: builder g++ not on PATH (need a C++ HOST compiler)" >&2; exit 1; }
command -v as >/dev/null 2>&1 || { echo "gcc-10.4.0: as (binutils) not on PATH" >&2; exit 1; }
[ -f "${GCC_MATH}/lib/libgmp.a" ] || { echo "gcc-10.4.0: gmp/mpfr/mpc missing at ${GCC_MATH}" >&2; exit 1; }
[ -f "${SR}/lib/libc.a" ] || { echo "gcc-10.4.0: musl-1.2.5 sysroot missing at ${SR}" >&2; exit 1; }
# The host g++ links the host libstdc++.a and needs its C++ headers; fail here rather
# than deep in the build.
[ -f /usr/lib/libstdc++.a ] || { echo "gcc-10.4.0: builder libstdc++.a missing at /usr/lib (the builder gcc must ship it as cxx_libs)" >&2; exit 1; }

# --- unpack (--no-same-owner: the sandbox user namespace cannot chown to the archived uid) ---
tar --no-same-owner -xf "${TARBALL}"
cd "${SRC}"

# --- host toolchain wrappers: force the host gcc/g++ onto the musl-1.2.5 sysroot ---
# GI = the host gcc's freestanding headers (stddef/stdarg).
GI="$("${BUILDER_GCC}" -print-file-name=include)"
[ -d "${GI}" ] || { echo "gcc-10.4.0: builder-gcc freestanding include dir not found ('${GI}')" >&2; exit 1; }

# The host libstdc++ headers, located via c++config.h so the wrapper follows whatever host version
# build.ncl imports: <base>/<ver>/<target>/bits/c++config.h.
CXXCFG="$(ls /usr/include/c++/*/${TARGET}/bits/c++config.h 2>/dev/null | head -n1)"
[ -n "${CXXCFG}" ] || { echo "gcc-10.4.0: builder libstdc++ target headers (c++config.h) not found under /usr/include/c++/*/${TARGET}/bits" >&2; exit 1; }
CXX_TGT_DIR="$(cd "$(dirname "${CXXCFG}")/.." && pwd)"   # /usr/include/c++/<ver>/<target>
CXX_BASE_DIR="$(dirname "${CXX_TGT_DIR}")"               # /usr/include/c++/<ver>

# C host wrapper: -nostdinc drops /usr; add the gcc freestanding and musl C headers; static musl link.
cat > "${BUILDROOT}/gcc-cc" <<WRAP
#!/bin/sh
INC="-isystem ${GI} -isystem ${SR}/include"
for a in "\$@"; do case "\$a" in -c|-S|-E) exec "${BUILDER_GCC}" -nostdinc \$INC "\$@" ;; esac; done
exec "${BUILDER_GCC}" -nostdinc \$INC -B "${SR}/lib" -L "${SR}/lib" -static "\$@"
WRAP
chmod +x "${BUILDROOT}/gcc-cc"
GCCCC="${BUILDROOT}/gcc-cc"

# C++ host wrapper. libstdc++'s <cstdlib> ends with `#include_next <stdlib.h>`, which must reach
# musl's stdlib.h. With the built-in C++ dirs kept, an -isystem musl dir sorts before them and the
# include_next steps past musl. So drop both built-in chains (-nostdinc -nostdinc++) and re-add
# explicitly in order: C++ headers, gcc freestanding, musl C headers.
cat > "${BUILDROOT}/gcc-cxx" <<WRAP
#!/bin/sh
INC="-isystem ${CXX_BASE_DIR} -isystem ${CXX_TGT_DIR} -isystem ${CXX_BASE_DIR}/backward -isystem ${GI} -isystem ${SR}/include"
for a in "\$@"; do case "\$a" in -c|-S|-E) exec "${BUILDER_GXX}" -nostdinc -nostdinc++ \$INC "\$@" ;; esac; done
exec "${BUILDER_GXX}" -nostdinc -nostdinc++ \$INC -B "${SR}/lib" -L "${SR}/lib" -static "\$@"
WRAP
chmod +x "${BUILDROOT}/gcc-cxx"
GCCCXX="${BUILDROOT}/gcc-cxx"

# --- musl source seds ---
# The siginfo/ucontext sed is a no-op from gcc-8 on (fixed upstream); kept as a guarded no-op.
for f in gcc/config/i386/linux-unwind.h; do
  [ -f "$f" ] && sed -i 's/struct siginfo/siginfo_t/g; s/struct ucontext/ucontext_t/g' "$f"
done
# libstdc++'s configure.host maps the -gnu triplet to os/gnu-linux, whose ctype_base.h uses
# glibc-internal _ISupper/_ISalpha constants musl lacks; os/generic carries its own. gcc's musl
# config keys on a *-linux-musl triplet, which these packages do not use.
sed -i 's|os/gnu-linux|os/generic|g' libstdc++-v3/configure.host

# --- mtime guard + regeneration-tool stubs ---
# The tarball ships every generated file; there is no bison/flex/autoconf here. Baseline every file
# old, then bump the shipped generated set newer so make never regenerates; stub the tools so a
# missed file fails by name. gawk and msgfmt are not stubbed: options.c is regenerated by gawk during
# the build, and --disable-nls plus MAKEINFO=true retire gettext/texinfo.
find . -exec touch -d '2001-01-01 00:00:00' {} +
# shellcheck disable=SC2046
touch $(find . \( -name configure -o -name 'config.in' -o -name 'config.h.in' -o -name 'aclocal.m4' \
                  -o -name 'Makefile.in' -o -name '*.info' -o -name '*.gmo' \
                  -o -name 'gengtype-lex.c' -o -name 'gengtype-lex.cc' \
                  -o -name '*.tab.c' -o -name '*.tab.h' \
                  -o -name 'plural.c' -o -name 'fixincl.x' \) -print) 2>/dev/null || true
STUBS="${BUILDROOT}/regen-stubs"; mkdir -p "${STUBS}"
for t in bison yacc flex lex m4 gperf perl autoconf autoheader autom4te aclocal automake autoreconf libtoolize; do
  printf '#!/bin/sh\necho "gcc-10.4.0 MODEL-B GUARD: %s invoked ($*) -> a generated file is being regenerated; add it to the touch list." >&2\nexit 1\n' "$t" > "${STUBS}/${t}"
  chmod +x "${STUBS}/${t}"
done
export PATH="${STUBS}:${PATH}"

# --- configure: out of tree, top level ---
#   CC/CXX: gcc is implemented in C++, so the host g++ builds it (no --disable-build-with-cxx).
#   --disable-bootstrap: single stage.
#   --without-isl: no Graphite; ISL is not in the closure.
#   --disable-lto: the lto plugin is a .so and cannot link against static musl.
#   --disable-libsanitizer/libssp/libgomp/libquadmath/libitm/libatomic: glibc-coupled optional runtime libs.
#   --disable-libstdcxx-pch: skip the precompiled-header build (memory).
#   --with-gmp/mpfr/mpc: the static trio at /usr/lib/gcc-math.
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

# --- build + install ---
# No-op fixincludes stub (musl headers need no fixing). CPATH/LIBRARY_PATH point the fresh xgcc's
# crtstuff/libgcc build at musl instead of the merged /usr. -j1: cc1plus and libstdc++ are the
# peak-memory steps.
printf '#!/bin/sh\nexit 0\n' > "${BUILDROOT}/${SRC}/fixincludes/fixinc.sh" 2>/dev/null || true
mkdir -p fixincludes; printf '#!/bin/sh\nexit 0\n' > fixincludes/fixinc.sh; chmod +x fixincludes/fixinc.sh
export CPATH="${SR}/include"
export LIBRARY_PATH="${SR}/lib"
# Target flags for the fresh xgcc: libstdc++'s configure runs a link test, and musl is static-only,
# so without -static plus musl's crt on the startfile path it sets GCC_NO_EXECUTABLES and aborts.
# CPATH/LIBRARY_PATH alone do not add -static. -g -O2 keeps the default target optimisation.
FT="-g -O2 -B ${SR}/lib -L ${SR}/lib -static"
make -j1 STMP_FIXINC= MAKEINFO=true CFLAGS_FOR_TARGET="${FT}" CXXFLAGS_FOR_TARGET="${FT}"
make -j1 STMP_FIXINC= MAKEINFO=true CFLAGS_FOR_TARGET="${FT}" CXXFLAGS_FOR_TARGET="${FT}" DESTDIR="${OUTPUT_DIR}" install

# --- smoke gate: the installed g++ must compile and run a C++14 program using static libstdc++ ---
# Same header order as the C++ wrapper so <cstdlib>'s include_next reaches musl's stdlib.h.
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
  echo "CXX-GATE: PASS (g++ compiled+ran C++14 + static libstdc++; got '${OUT}')" >&2
else
  echo "CXX-GATE: FAIL (rc=${grc} got '${OUT}', want '10'); tail:" >&2; tail -12 "${GATE}/err" >&2 || true
  exit 1
fi

# --- pin gate: disabled until stage0.answers carries the captured shas ---
# cd "${OUTPUT_DIR}" && sha256sum -c "${BUILDROOT}/stage0.answers"
