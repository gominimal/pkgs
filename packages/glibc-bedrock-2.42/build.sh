#!/bin/sh
# ============================================================================================
# B4 = packages/glibc-bedrock-2.42/build.sh  — COLD first-glibc-2.42 (scaffold 2026-07-02).
# NOT a patch to production packages/glibc/build.sh (that 38-line file is the STEP-5 native-rebuild
# shape: glibc already in /usr, ./configure && make).  This is the crosstool-NG/cross-LFS
# headers-first dance production never needed.
#
# Ingredients (all bedrock, seed-rooted): R12 stage0-gcc-15.2.0 (musl-linked, --disable-shared),
# R10 binutils-2.41 (unprefixed as/ld/ar), stage0-linux-headers-6.12.43 (/usr/include/{linux,asm,
# asm-generic}), R7 musl-1.2.5 at /usr/lib/musl-bedrock-1.2.5 (CC's OWN libc, NOT the target),
# R8 gmp/mpfr/mpc, image python3 3.14.5 + make/gawk/sed/grep/bison/m4/tar/xz.
#
# Full rationale + risk register: .staging-ctx/b4-glibc-recipe-design-2026-07-03.md
# ============================================================================================
set -ex
VERSION="${MINIMAL_ARG_VERSION:-2.42}"
GCCVER=15.2.0                                # matches R12 / build.ncl's second Source (Pass-2 only)
BUILDROOT="$(pwd)"
GCC=/usr/bin/gcc; GXX=/usr/bin/g++           # R12 native drivers
SR=/usr/lib/musl-bedrock-1.2.5               # R7 musl = CC's own libc (BUILD_CC only)
GI="$($GCC -print-file-name=include)"        # R12 freestanding hdrs (stddef/stdarg) — libc-agnostic
TGT=x86_64-linux-gnu
GCCLIBDIR=/usr/lib/gcc/$TGT/$GCCVER          # where R12's libgcc.a lives (Pass-2 overwrite target)
SYSROOT="$BUILDROOT/sysroot"                 # BUILD-TIME DESTDIR staging tree (NEVER shipped as-is)
PUB_REL=usr/lib/glibc-bedrock-2.42           # single-writer versioned sysroot (the anti-coin-flip output)

# ---- THE CROSS TRIPLE (solves the AC_TRY_RUN wedge) ----
# build_alias != host_alias (same cpu+os, distinct VENDOR) -> autoconf sets cross_compiling=yes
# (configure:1307) -> AC_RUN_IFELSE take cross defaults, no target binary executed.  Identical
# cpu(x86_64)+os(linux-gnu)+ABI(-gnu) => sysdeps selection is byte-identical to native => still a
# NATIVE x86_64 glibc.  HARDCODE both (do NOT use config.guess: nondeterministic + may emit ...-musl).
BUILD=x86_64-pc-linux-gnu
HOST=x86_64-bedrock-linux-gnu

# ============ infra guards (fail LOUD; all are configure critic_missing progs) ============
for t in gcc as ld ar ranlib bison gawk make sed grep m4 python3; do
  command -v "$t" >/dev/null 2>&1 || { echo "B4 infra: missing $t" >&2; exit 1; }
done
[ -x "$GCC" ] || { echo "B4 infra: R12 gcc not at $GCC" >&2; exit 1; }
[ -f "$SR/lib/libc.a" ]               || { echo "B4: R7 musl sysroot missing at $SR" >&2; exit 1; }
[ -d /usr/include/linux ] && [ -d /usr/include/asm ] || { echo "B4: linux UAPI missing" >&2; exit 1; }
[ -f /usr/lib/gcc-math/lib/libgmp.a ] || { echo "B4: R8 gmp/mpfr/mpc missing" >&2; exit 1; }
# /usr/include pollution is INERT for this build — glibc forces -nostdinc and consumes headers via
# --with-headers=$SYSROOT (below), and R12's baked --with-native-system-header-dir=$SR/include means
# bare $GCC never searches /usr/include either (even at configure time).  So this is ADVISORY ONLY:
# log what's present (image build-tools like python are glibc-linked and legitimately drag glibc
# headers into the composed sandbox /usr) but DO NOT abort.  The fail-shut correctness gate at the end
# (float/TLS/setjmp/locale/EH against the FRESH glibc) is the real backstop against silent corruption.
# See minimal_rootfs_nondeterministic_pollution.
if [ -e /usr/include/gnu/stubs.h ] \
   || { [ -e /usr/include/features.h ] && grep -q '__GLIBC__' /usr/include/features.h; }; then
  echo "B4 NOTE: /usr/include carries glibc headers (gnu/stubs.h or __GLIBC__ features.h) — inert here" \
       "(glibc uses --with-headers=\$SYSROOT; R12 native-header-dir=musl); correctness gate is the backstop." >&2
fi

# ============ seed kernel UAPI into the staging sysroot (glibc gets it via --with-headers, ============
# ============ NOT via the coin-flip /usr).  glibc headers #include <linux/...> so this MUST co-locate. ==
mkdir -p "$SYSROOT/usr/include" "$SYSROOT/usr/lib" "$SYSROOT/usr/include/gnu"
cp -a /usr/include/linux /usr/include/asm /usr/include/asm-generic "$SYSROOT/usr/include/"

# ============ BUILD_CC = R12 musl-static wrapper (verbatim R12 gcc-cc). ==================
# glibc RUNS build-host helper programs during the build; they need a working host libc.  Static musl
# is fine (throwaway, emit data).  This is the ONLY musl touch-point.
cat > "$BUILDROOT/build-cc" <<WRAP
#!/bin/sh
INC="-isystem $GI -isystem $SR/include"
for a in "\$@"; do case "\$a" in -c|-S|-E) exec $GCC -nostdinc \$INC "\$@";; esac; done
exec $GCC -nostdinc \$INC -B $SR/lib -L $SR/lib -static "\$@"
WRAP
chmod +x "$BUILDROOT/build-cc"; BUILD_CC="$BUILDROOT/build-cc"
# NOTE: CC for glibc itself is BARE $GCC.  glibc's own Makeconfig forces -nostdinc and builds the
# include path (-isystem $GI -isystem <--with-headers>), which NEUTRALIZES R12's baked
# --with-native-system-header-dir=$SR/include, so musl can never leak into a libc object.  Do NOT wrap
# CC with a hardcoded --sysroot that does not exist at Pass-1/3 time.

# ============ C++ host wrapper (verbatim R12 gcc-cxx) — ONLY used if Pass-2 host-compiles xgcc/cc1 =====
# include_next-SAFE posture: -nostdinc -nostdinc++ + EXPLICIT C++ dirs before musl (mirrors R12).
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

# ============ production-parity determinism flags (PRESERVED byte-for-byte; per-pass) ============
case "$(uname -m)" in x86_64) MARCH="-march=x86-64-v3";; aarch64) MARCH="-march=armv8-a";; *) MARCH="";; esac
CF="$MARCH -O2 -pipe -gno-record-gcc-switches"   # -gno-record: stop wrapper/sysroot flags leaking into DW_AT_producer
export LDFLAGS="-Wl,--build-id=none"
export ARFLAGS=Drc
TOOLS="AR=ar RANLIB=ranlib AS=as LD=ld NM=nm OBJCOPY=objcopy OBJDUMP=objdump READELF=readelf STRIP=strip"

tar --no-same-owner -xof "glibc-${VERSION}.tar.xz"
SRC="$BUILDROOT/glibc-${VERSION}"

# common configure (cold deltas vs production: distinct triple, --with-headers, BUILD_CC).
# NB: do NOT add libc_cv_forced_unwind / libc_cv_c_cleanup — VERIFIED ABSENT from glibc-2.42 configure
# (0 occurrences); those checks were removed ~2.26/2.35.  Adding dead cache vars is noise.
common_configure() {  # runs in $PWD build dir; re-emits -ffile-prefix-map for THIS dir
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

# ============ PASS 1 — glibc headers + csu crt + stub libc.so into $SYSROOT ============
# (cross-LFS "install start files").  Feeds the OPTIONAL Pass 2 libgcc rebuild.
mkdir -p "$BUILDROOT/b1"; cd "$BUILDROOT/b1"; common_configure
make install-bootstrap-headers=yes install-headers DESTDIR="$SYSROOT"
make -j"$(nproc)" csu/subdir_lib
install -Dm644 csu/crt1.o csu/crti.o csu/crtn.o -t "$SYSROOT/usr/lib"
$GCC -nostdlib -nostartfiles -shared -x c /dev/null -o "$SYSROOT/usr/lib/libc.so"   # dummy so -lc resolves
[ -f "$SYSROOT/usr/include/gnu/stubs.h" ] || touch "$SYSROOT/usr/include/gnu/stubs.h"

# ============ PASS 2 — OPTIONAL libgcc-vs-glibc rebuild, GATED ON THE COUPLING PROBE ============
# R12 built libgcc.a against MUSL.  glibc's Makeconfig links libc.so.6 with STATIC -lgcc (gnulib:=-lgcc);
# the baked libgcc.a code is libc-AGNOSTIC integer/soft-float arithmetic and x86_64 has NATIVE TLS
# (no emutls), so this is *probably* ABI-safe -> DEFAULT = SKIP Pass 2 (see design first_probe).
# ---- CRITICAL, load-bearing correction ----
# If the probe FAILS and Pass 2 IS run: -lgcc resolves via `gcc -print-libgcc-file-name` = R12's
# INTERNAL $GCCLIBDIR, which --sysroot / -B $SYSROOT do NOT override.  `install-target-libgcc
# DESTDIR=$SYSROOT` therefore changes NOTHING in Pass 3.  To actually consume the rebuilt libgcc you
# MUST overwrite R12's on-disk libgcc.a in place (install-target-libgcc DESTDIR=/) OR pass an explicit
# -B <rebuild-libgcc-dir> on the Pass-3 link.  Requires the gcc-15.2.0 SOURCE as a B4 Source.
if [ "${B4_REBUILD_LIBGCC:-0}" = 1 ]; then
  [ -n "$CXXCFG" ] || { echo "B4 Pass2: R12 libstdc++ C++ headers not found — cannot host-compile xgcc" >&2; exit 1; }
  tar --no-same-owner -xof "gcc-${GCCVER}.tar.xz"; mkdir -p "$BUILDROOT/b2"; cd "$BUILDROOT/b2"
  env CC="$BUILDROOT/build-cc" CXX="$BUILDROOT/gcc-cxx" AR=ar RANLIB=ranlib \
    "$BUILDROOT/gcc-${GCCVER}/configure" --prefix=/usr --build="$TGT" --host="$TGT" --target="$TGT" \
      --enable-languages=c --disable-shared --disable-bootstrap --disable-multilib --disable-nls \
      --disable-lto --disable-libsanitizer --disable-libssp --disable-libgomp --disable-libquadmath \
      --disable-libitm --disable-libatomic --without-isl \
      --with-gmp=/usr/lib/gcc-math --with-mpfr=/usr/lib/gcc-math --with-mpc=/usr/lib/gcc-math \
      --with-build-sysroot="$SYSROOT" --with-native-system-header-dir=/usr/include --program-transform-name=
  make -j"$(nproc)" all-target-libgcc CFLAGS_FOR_TARGET="-g -O2 -B $SYSROOT/usr/lib -L $SYSROOT/usr/lib"
  make install-target-libgcc DESTDIR=/    # overwrite R12's $GCCLIBDIR/libgcc.a with the glibc-coupled build
fi

# ============ PASS 3 — glibc FINAL (production step-5 shape; ABI flags verbatim) ============
mkdir -p "$BUILDROOT/b3"; cd "$BUILDROOT/b3"; common_configure
make -j"$(nproc)" MAKEINFO=:              # ':' matches glibc's `ifneq ($(strip $(MAKEINFO)),:)` guard; NOT 'true'
make install DESTDIR="$OUTPUT_DIR"        # SEALED artifact -> $OUTPUT_DIR/usr (prefix=/usr, ABI/interp correct)
make install DESTDIR="$SYSROOT"           # refresh staging tree for in-sandbox localedef + later rungs
sed '/RTLDLIST=/s@/usr@@g' -i "$OUTPUT_DIR/usr/bin/ldd"   # production line, PRESERVED

# ============ SINGLE-WRITER SYSROOT PUBLISH (mirrors R7 musl) — anti /usr coin-flip ============
# The SEALED artifact ALREADY ships to $OUTPUT_DIR/usr (that is what production/interp needs).  The
# versioned tree is an ADDITIONAL clean copy so B5 can build -nostdinc against a tree no other producer
# writes.  Kernel UAPI copied IN so glibc headers' <linux/...> includes resolve standalone.
PUB="$OUTPUT_DIR/$PUB_REL"
mkdir -p "$PUB/include" "$PUB/lib"
cp -a "$OUTPUT_DIR/usr/include/." "$PUB/include/"
cp -a /usr/include/linux /usr/include/asm /usr/include/asm-generic "$PUB/include/"   # co-locate UAPI
cp -a "$OUTPUT_DIR"/usr/lib/*.a "$OUTPUT_DIR"/usr/lib/*.so* "$OUTPUT_DIR"/usr/lib/*.o "$PUB/lib/" 2>/dev/null || true
cp -a "$OUTPUT_DIR/usr/lib/gconv" "$PUB/lib/gconv" 2>/dev/null || true
# libc.so is a linker SCRIPT with absolute GROUP(/usr/lib/...) paths -> repoint into the versioned tree
# so B5 (-L $PUB/lib) resolves within the clean sysroot, not the musl-polluted /usr:
sed -i "s@/usr/lib/@$PUB/lib/@g" "$PUB/lib/libc.so" 2>/dev/null || true

# ============ locale generation (production commands).  Runs the JUST-BUILT localedef => needs AVX2 ====
# (compiled -march=x86-64-v3, executed on the builder).  Non-fatal for the cold hop: the 368 pkgs need
# build-TIME links, not locales; defer to B5 if it fails cold.
mkdir -vp "$OUTPUT_DIR/usr/lib/locale"
( localedef --prefix="$OUTPUT_DIR" -i en_US -f ISO-8859-1 en_US \
  && localedef --prefix="$OUTPUT_DIR" -i en_US -f UTF-8 en_US.UTF-8 ) \
  || echo "WARN: cold locale gen failed; defer en_US to B5 (non-blocking)" >&2

# ============================================================================================
# FAIL-SHUT CORRECTNESS GATE (the R4-class silent-corruption tripwire).
# The chain has shipped a SILENTLY wrong libc twice (R4 fmt_fp long-double zeroed .data; tcc-mes
# >=4-arg miscompile).  "compiles" != "correct".  Exercise, STATIC-linked against the FRESH glibc:
#   (a) float/printf: long-double %.1Lf, %.17g, %a  <- the R4 fmt_fp class
#   (b) __thread TLS write in one TU, read via a function in a SECOND TU
#   (c) setjmp/longjmp round-trip
#   (d) locale: setlocale(LC_ALL,"C") + localeconv decimal_point (locale SUBSYSTEM, no generated data)
#   (e) STATIC C++ throw/catch in ONE binary (-static-libgcc -static-libstdc++; uses libgcc_eh.a which
#       R12 --disable-shared DID build) -> validates static EH unwind tables
# Cross-DSO C++ EH + backtrace(3) are DEFERRED to B5 (R12 is --disable-shared: NO libgcc_s.so.1 exists
# anywhere yet).  FAIL-SHUT: any mismatch => exit 1 (no seal).
# ============================================================================================
GATE="$BUILDROOT/b4gate"; rm -rf "$GATE"; mkdir -p "$GATE"
GINC="-nostdinc -isystem $GI -isystem $PUB/include"     # gcc freestanding + fresh-glibc headers (UAPI co-located)
# -no-pie forces the classic crt1.o static link (NOT static-pie via rcrt1.o) regardless of R12's default-PIE
# posture (design "STILL TO CONFIRM"); crt1.o/crti.o/crtn.o are the startfiles Pass 1 installed.
GLNK="-static -no-pie -B $PUB/lib -L $PUB/lib"          # static startfiles + libc.a from the versioned tree

# --- TU 2: __thread defined here, read via a function (proves cross-TU TLS) ---
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

  /* (a) long-double + double formatting — the R4 fmt_fp class */
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

  if (fails){ fprintf(stderr, "B4-GATE-C: FAIL (%d checks)\n", fails); return 1; }
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
  echo "B4-GATE-C: PASS (float/TLS/setjmp/locale correct against fresh glibc)" >&2
else
  echo "B4-GATE-C: FAIL (rc=$crc, out='$COUT'); tail:" >&2; tail -20 "$GATE/cc.err" >&2 || true
  exit 1
fi

# --- (e) STATIC C++ throw/catch (libgcc_eh.a static unwind tables) ---
# NB (arbitration point): R12's libstdc++.a + libgcc_eh.a were built against MUSL.  A clean PASS here
# proves the static EH tables survive the glibc link; a link/run FAILURE is the signal that the
# libgcc-vs-glibc coupling (design risk register [high]) is REAL -> run Pass 2 (B4_REBUILD_LIBGCC=1)
# OR demote this sub-gate to B5.  Kept FATAL per the design's fail-shut posture.
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
  echo "B4-GATE-CXX: PASS (static throw/catch; libgcc_eh unwind OK against fresh glibc)" >&2
else
  echo "B4-GATE-CXX: FAIL (compile rc=$xrc, run rc=$ehrc) — see design risk [high] libgcc coupling; tail:" >&2
  tail -20 "$GATE/cxx.err" >&2 || true
  exit 1
fi
