#!/bin/sh
# gcc-15.2.0-glibc: builds gcc 15.2.0 (c, c++, fortran; shared libstdc++.so.6, libgcc_s.so.1, libgomp,
# libatomic, libquadmath) from gcc-15.2.0.tar.xz with stage0-gcc-15.2.0's gcc/g++ as CC/CXX,
# targeting the glibc-2.42 sysroot at /usr/lib/glibc-bedrock-2.42, assembled by binutils-2.46-glibc.
# Installed under /usr into $OUTPUT_DIR.
# phases: clean state, preconditions, libc.so fix, unpack, host wrappers, mtime guard, configure, build, install, correctness gates

# --- clean state: the build directory may persist between runs ---
# Start from an empty $OUTPUT_DIR and drop every top-level directory (derived build/source trees);
# inputs re-hydrate as top-level files. A stale partial install or a make tree built under an earlier
# environment would otherwise poison the gates.
[ -n "$OUTPUT_DIR" ] && [ -d "$OUTPUT_DIR" ] && find "$OUTPUT_DIR" -mindepth 1 -delete
mkdir -p "$OUTPUT_DIR"
for _d in ./*/; do [ -d "$_d" ] && find "$_d" -delete; done
echo "gcc-glibc COLD-TREE GUARD ran: remaining top-level dirs: $(ls -d ./*/ 2>/dev/null | tr '\n' ' ')" >&2
set -ex
VERSION="${MINIMAL_ARG_VERSION:-15.2.0}"
TARBALL="gcc-${VERSION}.tar.xz"
SRC="gcc-${VERSION}"
BUILDROOT="$(pwd)"
PREFIX=/usr
LIBDIR=/usr/lib
TARGET="x86_64-linux-gnu"
GCC_MATH=/usr/lib/gcc-math                 # libgmp/libmpfr/libmpc.a + headers (linked into cc1)
SR=/usr/lib/glibc-bedrock-2.42             # glibc-2.42 sysroot (headers + crt + libs + kernel UAPI)
LOADER="$SR/lib/ld-linux-x86-64.so.2"

BUILDER_GCC="$(command -v gcc || true)"
BUILDER_GXX="$(command -v g++ || command -v ${TARGET}-g++ || true)"
[ -n "${BUILDER_GCC}" ] || { echo "gcc-glibc: builder gcc not on PATH" >&2; exit 1; }
[ -n "${BUILDER_GXX}" ] || { echo "gcc-glibc: builder g++ (C++ HOST compiler) not on PATH" >&2; exit 1; }
command -v as >/dev/null 2>&1 || { echo "gcc-glibc: as (binutils-2.46-glibc) not on PATH" >&2; exit 1; }
[ -f "${GCC_MATH}/lib/libgmp.a" ] || { echo "gcc-glibc: gmp/mpfr/mpc missing at ${GCC_MATH}" >&2; exit 1; }
[ -e "${SR}/lib/libc.so" ]        || { echo "gcc-glibc: glibc sysroot missing at ${SR} (libc.so)" >&2; exit 1; }
[ -f "${SR}/lib/crt1.o" ]         || { echo "gcc-glibc: glibc startfiles missing at ${SR}/lib (crt1.o)" >&2; exit 1; }
[ -f "${SR}/lib/Scrt1.o" ]        || { echo "gcc-glibc: glibc PIE startfiles missing at ${SR}/lib (Scrt1.o — --enable-default-pie gate link needs it)" >&2; exit 1; }
[ -e "${LOADER}" ]                || { echo "gcc-glibc: glibc loader missing at ${LOADER}" >&2; exit 1; }
[ -f /usr/lib/libstdc++.a ]       || { echo "gcc-glibc: builder libstdc++.a missing at /usr/lib" >&2; exit 1; }

# Drop build-id from host binaries (determinism parity with binutils-2.46-glibc).
export LDFLAGS="-Wl,--build-id=none"

# libc.so linker-script fix (same as binutils-2.46-glibc): the sysroot's libc.so may carry the glibc
# build's staging prefix in its GROUP() paths; regenerate a corrected copy that ld searches first.
FIXLIB="${BUILDROOT}/glibc-fixlib"; mkdir -p "${FIXLIB}"
sed -E "s@[^ ()]*/(libc\.so\.6|libc_nonshared\.a|ld-linux-x86-64\.so\.2)@${SR}/lib/\1@g" \
  "${SR}/lib/libc.so" > "${FIXLIB}/libc.so"
grep -q '/build/output' "${FIXLIB}/libc.so" && { echo "gcc-glibc: libc.so fixup failed" >&2; exit 1; }

# --- unpack (--no-same-owner: the sandbox user namespace cannot chown to the archived uid) ---
tar --no-same-owner -xf "${TARBALL}"
cd "${SRC}"

# --- lib64 -> lib ---
# As in the production gcc package: map the m64 multilib osdir so the built gcc searches /usr/lib,
# where this glibc installs its libraries (libc_cv_slibdir=/usr/lib).
case "$(uname -m)" in
  x86_64)  sed -e '/m64=/s/lib64/lib/'      -i.orig gcc/config/i386/t-linux64 ;;
  aarch64) sed -e '/mabi.lp64=/s/lib64/lib/' -i.orig gcc/config/aarch64/t-aarch64-linux ;;
esac

# --- host toolchain wrappers: the host gcc/g++ onto the glibc-2.42 sysroot (dynamic, no -static) ---
# GI = the host gcc's freestanding headers (stddef/stdarg).
GI="$("${BUILDER_GCC}" -print-file-name=include)"
[ -d "${GI}" ] || { echo "gcc-glibc: builder-gcc freestanding include dir not found ('${GI}')" >&2; exit 1; }

# The host libstdc++ headers, located via c++config.h.
CXXCFG="$(ls /usr/include/c++/*/${TARGET}/bits/c++config.h 2>/dev/null | head -n1)"
[ -n "${CXXCFG}" ] || { echo "gcc-glibc: builder libstdc++ target headers (c++config.h) not found under /usr/include/c++/*/${TARGET}/bits" >&2; exit 1; }
CXX_TGT_DIR="$(cd "$(dirname "${CXXCFG}")/.." && pwd)"   # /usr/include/c++/<ver>/<target>
CXX_BASE_DIR="$(dirname "${CXX_TGT_DIR}")"               # /usr/include/c++/<ver>

# C host wrapper: -nostdinc drops /usr; add the gcc freestanding and glibc C headers; dynamic glibc
# link with the sysroot loader and rpath baked in.
cat > "${BUILDROOT}/gcc-cc" <<WRAP
#!/bin/sh
INC="-isystem ${GI} -isystem ${SR}/include"
for a in "\$@"; do case "\$a" in -c|-S|-E) exec "${BUILDER_GCC}" -nostdinc \$INC "\$@" ;; esac; done
exec "${BUILDER_GCC}" -nostdinc \$INC -L "${FIXLIB}" -B "${SR}/lib" -L "${SR}/lib" -Wl,--dynamic-linker="${SR}/lib/ld-linux-x86-64.so.2" -Wl,-rpath,"${SR}/lib" "\$@"
WRAP
chmod +x "${BUILDROOT}/gcc-cc"
GCCCC="${BUILDROOT}/gcc-cc"

# C++ host wrapper: drop both built-in include chains and re-add in order (C++ headers, gcc
# freestanding, glibc C headers) so <cstdlib>'s include_next <stdlib.h> resolves inside the sysroot.
# The host libstdc++.a was built against musl and is linked into glibc-dynamic host programs here;
# the gates below check the result.
cat > "${BUILDROOT}/gcc-cxx" <<WRAP
#!/bin/sh
INC="-isystem ${CXX_BASE_DIR} -isystem ${CXX_TGT_DIR} -isystem ${CXX_BASE_DIR}/backward -isystem ${GI} -isystem ${SR}/include"
for a in "\$@"; do case "\$a" in -c|-S|-E) exec "${BUILDER_GXX}" -nostdinc -nostdinc++ \$INC "\$@" ;; esac; done
exec "${BUILDER_GXX}" -nostdinc -nostdinc++ \$INC -L "${FIXLIB}" -B "${SR}/lib" -L "${SR}/lib" -Wl,--dynamic-linker="${SR}/lib/ld-linux-x86-64.so.2" -Wl,-rpath,"${SR}/lib" "\$@"
WRAP
chmod +x "${BUILDROOT}/gcc-cxx"
GCCCXX="${BUILDROOT}/gcc-cxx"

# --- source seds ---
# The siginfo/ucontext sed is a no-op from gcc-8 on; kept as a guarded no-op. No os/generic sed
# here: that was a musl ctype workaround, and glibc wants libstdc++'s os/gnu-linux config.
for f in gcc/config/i386/linux-unwind.h; do
  [ -f "$f" ] && sed -i 's/struct siginfo/siginfo_t/g; s/struct ucontext/ucontext_t/g' "$f"
done

# --- mtime guard + regeneration-tool stubs ---
# The tarball ships every generated file; there is no bison/flex/autoconf here. Baseline every file
# old, then bump the shipped generated set newer so make never regenerates; stub the tools so a
# missed file fails by name.
find . -exec touch -d '2001-01-01 00:00:00' {} +
# shellcheck disable=SC2046
touch $(find . \( -name configure -o -name 'config.in' -o -name 'config.h.in' -o -name 'aclocal.m4' \
                  -o -name 'Makefile.in' -o -name '*.info' -o -name '*.gmo' \
                  -o -name 'gengtype-lex.c' -o -name 'gengtype-lex.cc' \
                  -o -name '*.tab.c' -o -name '*.tab.h' \
                  -o -name 'plural.c' -o -name 'fixincl.x' \) -print) 2>/dev/null || true
STUBS="${BUILDROOT}/regen-stubs"; mkdir -p "${STUBS}"
for t in bison yacc flex lex m4 gperf perl autoconf autoheader autom4te aclocal automake autoreconf libtoolize; do
  printf '#!/bin/sh\necho "gcc-glibc MODEL-B GUARD: %s invoked ($*) -> a generated file is being regenerated; add it to the touch list." >&2\nexit 1\n' "$t" > "${STUBS}/${t}"
  chmod +x "${STUBS}/${t}"
done
export PATH="${STUBS}:${PATH}"

# --- configure: out of tree, top level, production gcc flags (glibc-linked, shared) ---
#   --enable-languages=c,c++,fortran and --enable-shared: the production runtime lib set.
#   --enable-default-pie --enable-default-ssp: production hardening defaults.
#   --disable-fixincludes: glibc headers need no fixing.
#   --disable-bootstrap: single stage.  --without-isl: no Graphite.
#   --with-gmp/mpfr/mpc: the static trio at /usr/lib/gcc-math (linked into cc1; libc-agnostic).
#   No --with-native-system-header-dir: the built gcc defaults to /usr/include.
#   No --with-system-zlib: gcc's bundled zlib is used.
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

# --- build + install ---
# CPATH/LIBRARY_PATH pin the fresh xgcc's target-lib build to the glibc sysroot.
export CPATH="${SR}/include"
export LIBRARY_PATH="${SR}/lib"
# Target flags for the fresh xgcc, which links the target libs (libgcc_s.so first) with these flags,
# not via the host wrappers. -L FIXLIB first so -lc finds the corrected libc.so script.
# --dynamic-linker: target-lib configures run freshly linked conftests and the sandbox has no /lib64.
# -rpath: without it those conftests resolve libc from the merged /usr and die "cannot run C compiled
# programs". Joined -L/-B forms: libtool's link mode rejects the two-token form.
FT="-g -O2 -L${FIXLIB} -B${SR}/lib -L${SR}/lib -Wl,--dynamic-linker=${SR}/lib/ld-linux-x86-64.so.2 -Wl,-rpath,${SR}/lib"
make -j"$(nproc)" MAKEINFO=true CFLAGS_FOR_TARGET="${FT}" CXXFLAGS_FOR_TARGET="${FT}"
make -j"$(nproc)" MAKEINFO=true CFLAGS_FOR_TARGET="${FT}" CXXFLAGS_FOR_TARGET="${FT}" DESTDIR="${OUTPUT_DIR}" install

# --- correctness gate: the installed g++, glibc-dynamic against the fresh libstdc++.so.6/libgcc_s.so.1 ---
#   (a) throw an exception across a DSO boundary (cross-DSO EH through libgcc_s.so.1);
#   (b) backtrace(3) returns frames (glibc + libgcc_s unwinder);
#   (c) long-double / %.17g / %a printf;
#   (d) __thread TLS across two translation units.
XGXX="${OUTPUT_DIR}/usr/bin/g++"
[ -x "${XGXX}" ] || XGXX="${OUTPUT_DIR}/usr/bin/${TARGET}-g++"
GATE="${BUILDROOT}/b5gate"; rm -rf "${GATE}"; mkdir -p "${GATE}"
CB="${OUTPUT_DIR}/usr/include/c++/${VERSION}"
GIX="$("${XGXX}" -print-file-name=include)"
GXXINC="-nostdinc -nostdinc++ -isystem ${CB} -isystem ${CB}/${TARGET} -isystem ${CB}/backward -isystem ${GIX} -isystem ${SR}/include"
# -L FIXLIB first so the installed gcc/g++ resolve -lc via the corrected libc.so script. The gate
# binary bakes the sysroot loader as PT_INTERP and a RUNPATH into the fresh target libs plus the
# sysroot, and is exec'd directly with no LD_LIBRARY_PATH: the shape every consumer of this compiler
# runs. Running it via `ld.so --library-path` instead takes CET enablement from the loader (this
# glibc is built --enable-cet) and turns on shadow stacks on Intel hardware, where the unmarked
# fresh libgcc_s unwinder then trips on a cross-DSO throw.
GLNK="-L${FIXLIB} -B${SR}/lib -L${SR}/lib -L${OUTPUT_DIR}/usr/lib -Wl,--dynamic-linker=${LOADER} -Wl,-rpath,${OUTPUT_DIR}/usr/lib:${SR}/lib"
GRUN_LIBS="${OUTPUT_DIR}/usr/lib:${SR}/lib"

# --- shared lib: throws across the DSO boundary ---
cat > "${GATE}/thrower.cpp" <<'EOF'
struct E { int v; };
void do_throw(int x){ throw E{x}; }
EOF
# --- main: catches the cross-DSO throw + backtrace(3) ---
cat > "${GATE}/main.cpp" <<'EOF'
#include <string.h>
#include <stdio.h>
#include <cstdio>
#include <execinfo.h>
struct E { int v; };
void do_throw(int);
int main(int, char**, char** envp){
  { FILE* f = fopen("/proc/self/status", "r"); char l[256];
    while (f && fgets(l, sizeof l, f)) if (strstr(l, "x86_Thread_features")) fputs(l, stderr);
    if (f) fclose(f);
    size_t n = 0; for (char** e = envp; *e; ++e) n += strlen(*e) + 1;
    fprintf(stderr, "GATE env bytes=%zu\n", n); }
  int fails = 0;
  try { do_throw(7); }
  catch (const E& e){ if (e.v != 7){ fprintf(stderr, "GATE xdso-eh: v=%d want 7\n", e.v); fails++; } }
  catch (...) { fprintf(stderr, "GATE xdso-eh: wrong type caught\n"); fails++; }
  void* bt[16];
  int n = backtrace(bt, 16);
  if (n <= 0){ fprintf(stderr, "GATE backtrace: n=%d\n", n); fails++; }
  if (fails){ fprintf(stderr, "GATE-CXX: FAIL (%d)\n", fails); return 1; }
  printf("OK\n");
  return 0;
}
EOF
set +e
"${XGXX}" -std=gnu++14 -fPIC -shared ${GXXINC} ${GLNK} "${GATE}/thrower.cpp" -o "${GATE}/libthrower.so" 2>"${GATE}/cxx.err"
src=$?
"${XGXX}" -std=gnu++14 ${GXXINC} ${GLNK} -L "${GATE}" -Wl,-rpath,"${GATE}" "${GATE}/main.cpp" -lthrower -o "${GATE}/xdso" 2>>"${GATE}/cxx.err"
mrc=$?
COUT="<compile-failed>"
if [ $src -eq 0 ] && [ $mrc -eq 0 ]; then
  # direct exec, RUNPATH-resolved, no LD_LIBRARY_PATH (libthrower via -rpath $GATE)
  COUT="$(timeout 30 "${GATE}/xdso" 2>>"${GATE}/cxx.err" | tail -1)"
fi
set -e
if [ "${COUT}" = "OK" ]; then
  echo "GATE-CXX: PASS (cross-DSO C++ EH via libgcc_s.so.1 + backtrace against fresh glibc)" >&2
else
  echo "GATE-CXX: FAIL (thrower rc=$src main rc=$mrc out='${COUT}'); tail:" >&2; tail -20 "${GATE}/cxx.err" >&2 || true
  echo "GATE-CXX diag: loaded libs (ld.so --list):" >&2
  "$SR/lib/ld-linux-x86-64.so.2" --library-path "$GATE:$GRUN_LIBS" --list "$GATE/xdso" >&2 2>&1 || true
  for _l in "$OUTPUT_DIR"/usr/lib/libstdc++.so.6 "$OUTPUT_DIR"/usr/lib/libgcc_s.so.1 "$GATE/xdso" "$GATE/libthrower.so"; do
    echo "  dtags $_l: $(readelf -d "$_l" 2>/dev/null | grep -iE 'RPATH|RUNPATH|NEEDED' | tr -s ' ' | tr '\n' ';')" >&2
  done
  echo "  stack-protector default: $("$XGXX" -Q --help=common 2>/dev/null | grep -E 'fstack-protector' | tr -s ' ' | tr '\n' ';')" >&2
  # CET / shadow-stack diagnostics: hardware flag, kernel thread features, ELF property notes.
  echo "  cpu shstk flag: $(grep -c -w shstk /proc/cpuinfo 2>/dev/null) cores; kernel thread features: $(grep -i x86_Thread_features /proc/self/status 2>/dev/null | tr -s ' ')" >&2
  for _l in "$GATE/xdso" "$GATE/libthrower.so" "$OUTPUT_DIR"/usr/lib/libstdc++.so.6 "$OUTPUT_DIR"/usr/lib/libgcc_s.so.1 "$SR/lib/libc.so.6"; do
    echo "  cet-notes $_l: $(readelf -n "$_l" 2>/dev/null | grep -iE 'x86 feature|IBT|SHSTK' | tr -s ' ' | tr '\n' ';')" >&2
  done
  set +e
  _v1=$(GLIBC_TUNABLES=glibc.cpu.x86_shstk=off:glibc.cpu.x86_ibt=off timeout 30 "$SR/lib/ld-linux-x86-64.so.2" --library-path "$GATE:$GRUN_LIBS" "$GATE/xdso" 2>&1); _r1=$?
  echo "  variant A (same binaries, SHSTK/IBT tunables OFF): rc=$_r1 out='$_v1'" >&2
  "$XGXX" -std=gnu++14 -fPIC -shared -fno-stack-protector -fcf-protection=none $GXXINC $GLNK "$GATE/thrower.cpp" -o "$GATE/libthrower2.so" 2>/dev/null \
    && "$XGXX" -std=gnu++14 -fno-stack-protector -fcf-protection=none $GXXINC $GLNK -L "$GATE" "$GATE/main.cpp" -l:libthrower2.so -o "$GATE/xdso2" 2>/dev/null \
    && { _v2=$(timeout 30 "$SR/lib/ld-linux-x86-64.so.2" --library-path "$GATE:$GRUN_LIBS" "$GATE/xdso2" 2>&1); _r2=$?; echo "  variant B (-fno-stack-protector -fcf-protection=none): rc=$_r2 out='$_v2'" >&2; } \
    || echo "  variant B: compile failed" >&2
  _v3=$(GLIBC_TUNABLES=glibc.malloc.check=0 LD_LIBRARY_PATH="$GATE:$GRUN_LIBS" timeout 30 "$GATE/xdso" 2>&1 | tail -1); _r3=${PIPESTATUS:-$?}
  echo "  variant C (direct exec, INERT tunable — env-layout control): out='$_v3'" >&2
  _v4=$(GLIBC_TUNABLES=glibc.cpu.x86_shstk=off LD_LIBRARY_PATH="$GATE:$GRUN_LIBS" timeout 30 "$GATE/xdso" 2>&1 | tail -1)
  echo "  variant D (direct exec, shstk=off only): out='$_v4'" >&2
  _v5=$(LD_LIBRARY_PATH="$GATE:$GRUN_LIBS" XXXPAD=$(printf 'x%.0s' $(seq 1 64)) timeout 30 "$GATE/xdso" 2>&1 | tail -1)
  echo "  variant E (direct exec, +64-byte junk env var): out='$_v5'" >&2
  # Isolate LD_LIBRARY_PATH from the launch form and from C++ entirely:
  _f=$(timeout 30 "$SR/lib/ld-linux-x86-64.so.2" --library-path "$GATE:$GRUN_LIBS" "$GATE/xdso" 2>&1 | tail -1)
  echo "  variant F (loader form, NO env vars at all): out='$_f'" >&2
  _g=$(LD_LIBRARY_PATH=/nonexistent timeout 30 "$SR/lib/ld-linux-x86-64.so.2" --library-path "$GATE:$GRUN_LIBS" "$GATE/xdso" 2>&1 | tail -1)
  echo "  variant G (loader form + LD_LIBRARY_PATH=/nonexistent): out='$_g'" >&2
  printf '#include <stdio.h>\nint main(){ puts("HELLO-OK"); return 0; }\n' > "$GATE/hello.c"
  "$OUTPUT_DIR/usr/bin/gcc" -nostdinc -isystem "$GIX" -isystem "$SR/include" $GLNK "$GATE/hello.c" -o "$GATE/hello" 2>/dev/null \
    && { _h=$(LD_LIBRARY_PATH="$GATE:$GRUN_LIBS" timeout 30 "$GATE/hello" 2>&1 | tail -1); echo "  variant H (plain C hello, direct exec, LD_LIBRARY_PATH set): out='$_h'" >&2; \
         _i=$(timeout 30 "$GATE/hello" 2>&1 | tail -1); echo "  variant I (plain C hello, direct exec, no env): out='$_i'" >&2; } \
    || echo "  variant H/I: hello compile failed" >&2
  echo "  ld.so identity: $(sha256sum "$SR/lib/ld-linux-x86-64.so.2" | cut -c1-16)  libc: $(sha256sum "$SR/lib/libc.so.6" | cut -c1-16)  build-id: $(readelf -n "$SR/lib/ld-linux-x86-64.so.2" 2>/dev/null | grep -i 'Build ID' | tr -s ' ')" >&2
  echo "  LD_DEBUG (hello, direct exec + LD_LIBRARY_PATH) search paths:" >&2
  LD_LIBRARY_PATH="$GATE:$GRUN_LIBS" LD_DEBUG=libs timeout 30 "$GATE/hello" 2>&1 | grep -E 'search path|trying file|initialize' | head -6 | cut -c1-200 >&2 || true
  echo "  VERDICT-KEY: F=loader-noenv G=loader+bogusLDLP H=C-hello+LDLP I=C-hello-noenv (A/B passed with no LD_LIBRARY_PATH; C/D/E + primary smashed with it)" >&2
  set -e
  exit 1
fi

# --- (c)+(d) float / TLS correctness (C, glibc-dynamic) ---
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
  if (fails){ fprintf(stderr, "GATE-C: FAIL (%d)\n", fails); return 1; }
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
  echo "GATE-C: PASS (float/long-double/TLS correct against fresh glibc)" >&2
else
  echo "GATE-C: FAIL (rc=$crc out='${FOUT}'); tail:" >&2; tail -20 "${GATE}/cc.err" >&2 || true
  exit 1
fi

# No pin gate: a different compiler than the prebuilt built this, so byte parity with the prebuilt
# is not expected. See stage0.answers.
