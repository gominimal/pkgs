#!/bin/sh
# glibc-bedrock-2.42: cold from-source build of glibc 2.42 from glibc-2.42.tar.xz with stage0-gcc-15.2.0
# (musl-linked, static) as CC, stage0-binutils-2.41 as as/ld, and the stage0 kernel UAPI headers.
# Installs to /usr in $OUTPUT_DIR and publishes a copy as the versioned single-writer sysroot
# usr/lib/glibc-bedrock-2.42/{include,lib}. Unlike the production glibc package (a native rebuild with
# glibc already in /usr), this is a headers-first cross-style build with no glibc present.
# On aarch64 the prebuilt artifact from build.ncl's Arm64 Source is extracted instead of building.
# phases: arm extract, clean state, preconditions, staging sysroot, wrappers, pass 1 (headers + crt), optional pass 2 (libgcc), pass 3 (glibc), sysroot publish, locales, correctness gates, linker-script rewrite
if [ "$(uname -m)" = "aarch64" ]; then
  set -ex
  ART=$(ls stage0-glibc-*-aarch64.tar.zst /build/stage0-glibc-*-aarch64.tar.zst 2>/dev/null | head -1)
  [ -n "$ART" ] || { echo "FATAL: arm glibc artifact not hydrated" >&2; exit 1; }
  mkdir -p "$OUTPUT_DIR"
  tar --zstd --no-same-owner -xf "$ART" -C "$OUTPUT_DIR"
  V="${MINIMAL_ARG_VERSION:-2.42}"
  [ -e "$OUTPUT_DIR/usr/lib/glibc-bedrock-$V/lib/ld-linux-aarch64.so.1" ] \
    || { echo "FATAL: arm loader missing after extract" >&2; ls "$OUTPUT_DIR/usr/lib" >&2; exit 1; }
  [ -f "$OUTPUT_DIR/usr/lib/glibc-bedrock-$V/include/stdio.h" ] \
    || { echo "FATAL: arm glibc headers missing after extract" >&2; exit 1; }
  exit 0
fi

# --- clean state: the build directory may persist between runs ---
# Start from an empty $OUTPUT_DIR and drop every top-level directory (derived build/source trees);
# inputs re-hydrate as top-level files. A stale partial install or a make tree built under an earlier
# environment would otherwise poison the gates.
[ -n "$OUTPUT_DIR" ] && [ -d "$OUTPUT_DIR" ] && find "$OUTPUT_DIR" -mindepth 1 -delete
mkdir -p "$OUTPUT_DIR"
for _d in ./*/; do [ -d "$_d" ] && find "$_d" -delete; done
set -ex
VERSION="${MINIMAL_ARG_VERSION:-2.42}"
GCCVER=15.2.0                                # matches build.ncl's second Source (pass 2 only)
BUILDROOT="$(pwd)"
GCC=/usr/bin/gcc; GXX=/usr/bin/g++           # host drivers
SR=/usr/lib/musl-bedrock-1.2.5               # musl sysroot: the host compiler's own libc (BUILD_CC only)
GI="$($GCC -print-file-name=include)"        # host gcc freestanding headers (stddef/stdarg)
TGT=x86_64-linux-gnu
GCCLIBDIR=/usr/lib/gcc/$TGT/$GCCVER          # where the host libgcc.a lives (pass 2 overwrite target)
SYSROOT="$BUILDROOT/sysroot"                 # build-time DESTDIR staging tree, never shipped as is
PUB_REL=usr/lib/glibc-bedrock-2.42           # versioned single-writer sysroot published in the output

# --- cross triple ---
# build_alias != host_alias (same cpu and os, distinct vendor) makes configure set cross_compiling=yes,
# so AC_RUN_IFELSE takes cross defaults instead of running target binaries that cannot exist yet.
# Identical cpu/os/ABI keeps the sysdeps selection native. Hardcoded: config.guess may emit -musl.
BUILD=x86_64-pc-linux-gnu
HOST=x86_64-bedrock-linux-gnu

# --- preconditions (configure's critic_missing programs) ---
for t in gcc as ld ar ranlib bison gawk make sed grep m4 python3; do
  command -v "$t" >/dev/null 2>&1 || { echo "glibc: missing $t" >&2; exit 1; }
done
[ -x "$GCC" ] || { echo "glibc: gcc not at $GCC" >&2; exit 1; }
[ -f "$SR/lib/libc.a" ]               || { echo "glibc: musl sysroot missing at $SR" >&2; exit 1; }
[ -d /usr/include/linux ] && [ -d /usr/include/asm ] || { echo "glibc: linux UAPI missing" >&2; exit 1; }
[ -f /usr/lib/gcc-math/lib/libgmp.a ] || { echo "glibc: gmp/mpfr/mpc missing" >&2; exit 1; }
# glibc headers in the merged /usr/include are inert here: glibc forces -nostdinc and takes headers
# from --with-headers, and the host gcc's native header dir is the musl sysroot. Log their presence;
# the correctness gate at the end is the backstop.
if [ -e /usr/include/gnu/stubs.h ] \
   || { [ -e /usr/include/features.h ] && grep -q '__GLIBC__' /usr/include/features.h; }; then
  echo "glibc NOTE: /usr/include carries glibc headers (gnu/stubs.h or __GLIBC__ features.h) — inert here" \
       "(glibc uses --with-headers=\$SYSROOT; the host gcc's native-header-dir is musl); correctness gate is the backstop." >&2
fi

# --- seed the kernel UAPI into the staging sysroot ---
# glibc headers include <linux/...>, and --with-headers must be self-contained.
mkdir -p "$SYSROOT/usr/include" "$SYSROOT/usr/lib" "$SYSROOT/usr/include/gnu"
cp -a /usr/include/linux /usr/include/asm /usr/include/asm-generic "$SYSROOT/usr/include/"

# --- BUILD_CC: the host gcc, static musl ---
# glibc runs build-host helper programs during the build; they only emit data, so static musl is fine.
cat > "$BUILDROOT/build-cc" <<WRAP
#!/bin/sh
INC="-isystem $GI -isystem $SR/include"
for a in "\$@"; do case "\$a" in -c|-S|-E) exec $GCC -nostdinc \$INC "\$@";; esac; done
exec $GCC -nostdinc \$INC -B $SR/lib -L $SR/lib -static "\$@"
WRAP
chmod +x "$BUILDROOT/build-cc"; BUILD_CC="$BUILDROOT/build-cc"
# CC for glibc itself is the bare host gcc: glibc's Makeconfig forces -nostdinc and builds its own
# include path from --with-headers, so musl never leaks into a libc object. Do not wrap CC with a
# --sysroot that does not exist at pass 1.

# --- C++ host wrapper (used only if pass 2 host-compiles xgcc/cc1) ---
# Drop both built-in include chains and re-add in order: C++ headers, gcc freestanding, musl C headers.
CXXCFG="$(ls /usr/include/c++/*/${TGT}/bits/c++config.h 2>/dev/null | head -n1)"
if [ -n "$CXXCFG" ]; then
  CXX_TGT_DIR="$(cd "$(dirname "$CXXCFG")/.." && pwd)"      # /usr/include/c++/<ver>/<target>
  CXX_BASE_DIR="$(dirname "$CXX_TGT_DIR")"                  # /usr/include/c++/<ver>
  cat > "$BUILDROOT/gcc-cxx" <<WRAP
#!/bin/sh
INC="-isystem $CXX_BASE_DIR -isystem $CXX_TGT_DIR -isystem $CXX_BASE_DIR/backward -isystem $GI -isystem $SR/include"
for a in "\$@"; do case "\$a" in -c|-S|-E) exec $GXX -nostdinc -nostdinc++ \$INC "\$@";; esac; done
exec $GXX -nostdinc -nostdinc++ \$INC -B $SR/lib -L $SR/lib -static "\$@"
WRAP
  chmod +x "$BUILDROOT/gcc-cxx"
fi

# --- production determinism flags, applied per pass ---
case "$(uname -m)" in x86_64) MARCH="-march=x86-64-v3";; aarch64) MARCH="-march=armv8-a";; *) MARCH="";; esac
CF="$MARCH -O2 -pipe -gno-record-gcc-switches"   # -gno-record: keep wrapper/sysroot flags out of DW_AT_producer
export LDFLAGS="-Wl,--build-id=none"
export ARFLAGS=Drc
TOOLS="AR=ar RANLIB=ranlib AS=as LD=ld NM=nm OBJCOPY=objcopy OBJDUMP=objdump READELF=readelf STRIP=strip"

tar --no-same-owner -xof "glibc-${VERSION}.tar.xz"
SRC="$BUILDROOT/glibc-${VERSION}"

# Common configure (deltas vs the production package: the cross triple, --with-headers, BUILD_CC).
# libc_cv_forced_unwind / libc_cv_c_cleanup are absent from glibc-2.42's configure; do not add them.
common_configure() {  # runs in $PWD build dir; re-emits -ffile-prefix-map for this dir
  echo "rootsbindir=/usr/sbin" > configparms
  env CC="$GCC" CXX="$GXX" BUILD_CC="$BUILD_CC" $TOOLS \
      CFLAGS="$CF -ffile-prefix-map=$(pwd)=/builddir" CXXFLAGS="$CF -ffile-prefix-map=$(pwd)=/builddir" \
      "$SRC/configure" \
        --prefix=/usr --host="$HOST" --build="$BUILD" \
        --with-headers="$SYSROOT/usr/include" \
        --enable-kernel=6.1 --enable-stack-protector=strong \
        --disable-nscd --disable-werror --without-selinux \
        libc_cv_slibdir=/usr/lib
}

# --- pass 1: glibc headers, csu crt files and a stub libc.so into $SYSROOT ---
mkdir -p "$BUILDROOT/b1"; cd "$BUILDROOT/b1"; common_configure
make install-bootstrap-headers=yes install-headers DESTDIR="$SYSROOT"
make -j"$(nproc)" csu/subdir_lib
install -Dm644 csu/crt1.o csu/crti.o csu/crtn.o -t "$SYSROOT/usr/lib"
$GCC -nostdlib -nostartfiles -shared -x c /dev/null -o "$SYSROOT/usr/lib/libc.so"   # dummy so -lc resolves
[ -f "$SYSROOT/usr/include/gnu/stubs.h" ] || touch "$SYSROOT/usr/include/gnu/stubs.h"

# --- pass 2 (optional, B4_REBUILD_LIBGCC=1): rebuild libgcc against glibc ---
# The host libgcc.a was built against musl, and glibc links libc.so.6 with static -lgcc. x86_64
# libgcc is libc-agnostic arithmetic with native TLS, so the default is to skip this pass.
# If run: -lgcc resolves via `gcc -print-libgcc-file-name` to the host's internal $GCCLIBDIR, which
# --sysroot/-B do not override, so the rebuilt libgcc must overwrite it in place (DESTDIR=/) or be
# passed with an explicit -B on the pass-3 link. Needs the gcc-15.2.0 source from build.ncl.
if [ "${B4_REBUILD_LIBGCC:-0}" = 1 ]; then
  [ -n "$CXXCFG" ] || { echo "glibc pass2: libstdc++ C++ headers not found — cannot host-compile xgcc" >&2; exit 1; }
  tar --no-same-owner -xof "gcc-${GCCVER}.tar.xz"; mkdir -p "$BUILDROOT/b2"; cd "$BUILDROOT/b2"
  env CC="$BUILDROOT/build-cc" CXX="$BUILDROOT/gcc-cxx" AR=ar RANLIB=ranlib \
    "$BUILDROOT/gcc-${GCCVER}/configure" --prefix=/usr --build="$TGT" --host="$TGT" --target="$TGT" \
      --enable-languages=c --disable-shared --disable-bootstrap --disable-multilib --disable-nls \
      --disable-lto --disable-libsanitizer --disable-libssp --disable-libgomp --disable-libquadmath \
      --disable-libitm --disable-libatomic --without-isl \
      --with-gmp=/usr/lib/gcc-math --with-mpfr=/usr/lib/gcc-math --with-mpc=/usr/lib/gcc-math \
      --with-build-sysroot="$SYSROOT" --with-native-system-header-dir=/usr/include --program-transform-name=
  make -j"$(nproc)" all-target-libgcc CFLAGS_FOR_TARGET="-g -O2 -B $SYSROOT/usr/lib -L $SYSROOT/usr/lib"
  make install-target-libgcc DESTDIR=/    # overwrite the host libgcc.a with the glibc-coupled build
fi

# --- pass 3: full glibc (production configure shape, ABI flags verbatim) ---
mkdir -p "$BUILDROOT/b3"; cd "$BUILDROOT/b3"; common_configure
make -j"$(nproc)" MAKEINFO=:              # ':' matches glibc's `ifneq ($(strip $(MAKEINFO)),:)` guard; 'true' does not
make install DESTDIR="$OUTPUT_DIR"        # the artifact: $OUTPUT_DIR/usr (prefix=/usr, interp correct)
make install DESTDIR="$SYSROOT"           # refresh the staging tree for in-sandbox localedef
sed '/RTLDLIST=/s@/usr@@g' -i "$OUTPUT_DIR/usr/bin/ldd"   # production line

# --- versioned single-writer sysroot ---
# /usr in the artifact is what production and the interpreter path need; the versioned tree is an
# additional clean copy that consumers build against with -nostdinc, so no other package can shadow
# it. Kernel UAPI is copied in so glibc's <linux/...> includes resolve standalone.
PUB="$OUTPUT_DIR/$PUB_REL"
mkdir -p "$PUB/include" "$PUB/lib"
cp -a "$OUTPUT_DIR/usr/include/." "$PUB/include/"
cp -a /usr/include/linux /usr/include/asm /usr/include/asm-generic "$PUB/include/"   # co-locate UAPI
cp -a "$OUTPUT_DIR"/usr/lib/*.a "$OUTPUT_DIR"/usr/lib/*.so* "$OUTPUT_DIR"/usr/lib/*.o "$PUB/lib/" 2>/dev/null || true
cp -a "$OUTPUT_DIR/usr/lib/gconv" "$PUB/lib/gconv" 2>/dev/null || true
# libc.so, libm.so and libm.a are linker scripts with absolute GROUP(/usr/lib/...) paths; every text
# script must be repointed into the versioned tree so a consumer linking -L $PUB/lib resolves within
# it. Two passes, because /usr is read-only and no symlink bridge is possible: pass 1 (here) points
# the scripts at the build-time staging path so the gate's ld resolves them; pass 2 (after the gate)
# flips them to the runtime install path and asserts that no staging path survives into the artifact.
LDSCRIPTS=""
for _ls in "$PUB"/lib/lib*.so "$PUB"/lib/lib*.a; do
  [ -f "$_ls" ] || continue
  head -c 64 "$_ls" | grep -qE 'GNU ld script|OUTPUT_FORMAT|GROUP' || continue
  sed -i "s@/usr/lib/@$PUB/lib/@g" "$_ls"
  LDSCRIPTS="$LDSCRIPTS $_ls"
  echo "  repointed linker script (build-time pass): $_ls" >&2
done

# --- locale generation (production commands) ---
# Runs the just-built localedef, compiled -march=x86-64-v3. Non-fatal: consumers need build-time
# links, not locales.
mkdir -vp "$OUTPUT_DIR/usr/lib/locale"
( localedef --prefix="$OUTPUT_DIR" -i en_US -f ISO-8859-1 en_US \
  && localedef --prefix="$OUTPUT_DIR" -i en_US -f UTF-8 en_US.UTF-8 ) \
  || echo "WARN: cold locale gen failed; defer en_US to gcc-15.2.0-glibc (non-blocking)" >&2

# --- correctness gate, static against the fresh glibc ---
#   (a) float/printf: long-double %.1Lf, %.17g, %a
#   (b) __thread TLS written in one TU, read via a function in a second TU
#   (c) setjmp/longjmp round trip
#   (d) locale: setlocale(LC_ALL,"C") + localeconv decimal_point (no generated locale data needed)
#   (e) static C++ throw/catch in one binary (-static-libgcc -static-libstdc++, via libgcc_eh.a)
# Cross-DSO C++ EH and backtrace(3) need libgcc_s.so.1, which the --disable-shared host gcc lacks;
# gcc-15.2.0-glibc tests those. Any mismatch exits 1.
GATE="$BUILDROOT/b4gate"; rm -rf "$GATE"; mkdir -p "$GATE"
GINC="-nostdinc -isystem $GI -isystem $PUB/include"     # gcc freestanding + fresh glibc headers (UAPI co-located)
# -no-pie forces the classic crt1.o static link regardless of the host gcc's default-PIE setting;
# crt1.o/crti.o/crtn.o are the startfiles pass 1 installed.
GLNK="-static -no-pie -B $PUB/lib -L $PUB/lib"          # static startfiles + libc.a from the versioned tree

# --- TU 2: __thread defined here, read via a function ---
cat > "$GATE/tls_b.c" <<'EOF'
__thread int tls_v = 7;
int tls_get(void) { return tls_v; }
EOF

# --- TU 1: float / setjmp / locale / TLS driver ---
cat > "$GATE/gate.c" <<'EOF'
#include <stdio.h>
#include <string.h>
#include <setjmp.h>
#include <locale.h>
extern __thread int tls_v;
extern int tls_get(void);
static jmp_buf jb;
static void jumper(int v){ longjmp(jb, v); }
int main(void){
  char b[64]; int fails = 0;

  /* (a) long-double + double formatting */
  long double ld = 1.5L;
  snprintf(b, sizeof b, "%.1Lf", ld);
  if (strcmp(b, "1.5") != 0){ fprintf(stderr, "GATE float Lf: got '%s' want '1.5'\n", b); fails++; }
  snprintf(b, sizeof b, "%.17g", 1.5 + 2.25);
  if (strcmp(b, "3.75") != 0){ fprintf(stderr, "GATE float g: got '%s' want '3.75'\n", b); fails++; }
  snprintf(b, sizeof b, "%a", 1.0);
  if (strcmp(b, "0x1p+0") != 0){ fprintf(stderr, "GATE float a: got '%s' want '0x1p+0'\n", b); fails++; }

  /* (b) __thread TLS across two TUs (write here, read in tls_b.c) */
  tls_v = 42;
  if (tls_get() != 42){ fprintf(stderr, "GATE tls: got %d want 42\n", tls_get()); fails++; }

  /* (c) setjmp/longjmp round-trip */
  int r = setjmp(jb);
  if (r == 0) jumper(99);
  else if (r != 99){ fprintf(stderr, "GATE setjmp: got %d want 99\n", r); fails++; }

  /* (d) locale subsystem (no generated-locale dependency) */
  if (setlocale(LC_ALL, "C") == NULL){ fprintf(stderr, "GATE locale: setlocale(C) NULL\n"); fails++; }
  else {
    struct lconv *lc = localeconv();
    if (lc == NULL || strcmp(lc->decimal_point, ".") != 0){
      fprintf(stderr, "GATE locale: decimal_point wrong\n"); fails++;
    }
  }

  if (fails){ fprintf(stderr, "GATE-C: FAIL (%d checks)\n", fails); return 1; }
  printf("OK\n");
  return 0;
}
EOF

set +e
"$GCC" $GINC $GLNK "$GATE/gate.c" "$GATE/tls_b.c" -o "$GATE/gate" 2>"$GATE/cc.err"
crc=$?
COUT="<compile-failed>"; [ $crc -eq 0 ] && COUT="$(timeout 30 "$GATE/gate" 2>>"$GATE/cc.err")"
set -e
if [ "$COUT" = "OK" ]; then
  echo "GATE-C: PASS (float/TLS/setjmp/locale correct against fresh glibc)" >&2
else
  echo "GATE-C: FAIL (rc=$crc, out='$COUT'); tail:" >&2; tail -20 "$GATE/cc.err" >&2 || true
  exit 1
fi

# --- (e) static C++ throw/catch (libgcc_eh.a static unwind tables) ---
# The host libstdc++.a and libgcc_eh.a were built against musl. A pass proves the static EH tables
# survive the glibc link; a failure means the libgcc/glibc coupling is real: run pass 2
# (B4_REBUILD_LIBGCC=1).
cat > "$GATE/eh.cpp" <<'EOF'
struct E { int v; };
int main(){
  try { throw E{7}; }
  catch (const E& e) { return e.v == 7 ? 0 : 2; }
  return 3;
}
EOF
set +e
"$GXX" -static -no-pie -static-libgcc -static-libstdc++ -B "$PUB/lib" -L "$PUB/lib" \
  "$GATE/eh.cpp" -o "$GATE/eh" 2>"$GATE/cxx.err"
xrc=$?
if [ $xrc -eq 0 ]; then timeout 30 "$GATE/eh"; ehrc=$?; else ehrc=$xrc; fi
set -e
if [ $ehrc -eq 0 ]; then
  echo "GATE-CXX: PASS (static throw/catch; libgcc_eh unwind OK against fresh glibc)" >&2
else
  echo "GATE-CXX: FAIL (compile rc=$xrc, run rc=$ehrc); tail:" >&2
  tail -20 "$GATE/cxx.err" >&2 || true
  exit 1
fi

# --- linker-script rewrite, pass 2: staging path -> runtime path ---
# Consumers hydrate the sysroot at /$PUB_REL, so shipped scripts must carry that path. The assert
# makes a surviving staging path fail the build instead of dangling in every consumer.
for _ls in $LDSCRIPTS; do
  sed -i "s@$PUB/lib/@/$PUB_REL/lib/@g" "$_ls"
  echo "  repointed linker script (runtime pass): $_ls" >&2
done
if [ -n "$LDSCRIPTS" ] && grep -l "$BUILDROOT\|/build/output" $LDSCRIPTS >/dev/null 2>&1; then
  echo "glibc FATAL: a linker script still carries a build-time path after pass 2:" >&2
  grep -l "$BUILDROOT\|/build/output" $LDSCRIPTS >&2
  exit 1
fi
