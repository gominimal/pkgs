#!/bin/sh
# build.sh — R4b (stage0-musl-1.1.24-cc2) driver.  The DETERMINISTIC second-pass musl.
#
# DERIVED from R4a (stage0-musl-1.1.24/build.sh) with ONE architectural change: the compiler is the
# CACHED, LOTTERY-FREE tcc-musl2 (musl-linked tcc-0.9.27 from s3), NOT the R3 mes-linked tcc.  Because
# tcc-musl2 has NO mes-libc allocator, it does NOT roll the per-sandbox arena lottery — its codegen is
# DETERMINISTIC.  So this is a single, straight build: extract → patch → configure → make → install →
# FLOAT gate → seal.  The R4a retry loop + tcc-retry crash wrapper are DELETED (there is no lottery to
# retry), and the FLOAT gate is FAIL-SHUT: a gate failure here is a REAL deterministic codegen/libc bug,
# NOT a lottery, so we exit 1 hard as a plain BuildScriptFailed — we do NOT carry the mes-m2/rc=139
# MesccArenaLottery marker (that would wrongly route a real bug to an infinite fresh-sandbox re-roll).
#
# WHAT BUILDS MUSL: CC=tcc-musl2 compiles every .c and assembles every .s with tcc's INTEGRATED assembler
# (no binutils `as` yet); AR="tcc-musl2 -ar" archives (no binutils `ar` yet); RANLIB=true is a no-op.
# musl is freestanding (-nostdinc, its OWN include/stddef.h + include/stdarg.h) and is only -c/-ar'd
# (never linked into an executable), so tcc's -static linker is not exercised by the compile.
#
# HEADER RESOLUTION (see build.ncl): the musl compile is -nostdinc -Iinclude, so stddef.h/stdarg.h come
# from musl's OWN tree — tcc-musl2 needs NO builtin-header dir installed.  The float gate below links
# against s3's libtcc1.a at /usr/lib/tcc/libtcc1.a (tcc-musl2's baked TCC_LIBGCC path).
set -ex

VERSION="${MINIMAL_ARG_VERSION:-1.1.24}"
SRC="musl-${VERSION}"
# Local files (build.sh, *.patch, stage0.answers) sit in the build root; remember it before cd.
BUILDROOT="$(pwd)"

# The DETERMINISTIC compiler + its libtcc1.a (both from s3).  tcc-musl2 bakes CONFIG_TCCDIR=/usr/lib/tcc,
# so its libtcc1.a lives at /usr/lib/tcc/libtcc1.a (s3's OutputLib path) — the float gate links it.
# If it is absent that is an INFRA defect (broken s3 edge), NOT a lottery, so fail-hard with a plain
# message (routes to BuildScriptFailed).
CC_MUSL2="/usr/bin/tcc-musl2"
LIBTCC1="/usr/lib/tcc/libtcc1.a"
command -v tcc-musl2 >/dev/null 2>&1 || { echo "R4b infra error: tcc-musl2 not on PATH (broken s3 edge)" >&2; exit 1; }
[ -f "${LIBTCC1}" ] || { echo "R4b float-gate infra error: libtcc1.a missing at ${LIBTCC1} (broken s3 edge)" >&2; exit 1; }

###########################################################################
# BUILD — a single deterministic pass (NO re-roll: tcc-musl2 does not lottery).
###########################################################################
cd "${BUILDROOT}"
rm -rf "${SRC}"
# --- unpack (Source is extract=false; we tar here per the bash-build convention) ---
tar -xf "${SRC}.tar.gz"
cd "${SRC}"

# --- patches: ONLY the four ARCH-NEUTRAL live-bootstrap patches + the five amd64-net-new patches (the
#     i386-specific ones do not apply to the x86_64 build — see build.ncl).  BYTE-IDENTICAL to R4a. ---
patch -Np1 -i "${BUILDROOT}/makefile.patch"               # tcc -ar can't make empty archives -> touch
patch -Np1 -i "${BUILDROOT}/madvise_preserve_errno.patch" # preserve errno across __madvise
patch -Np1 -i "${BUILDROOT}/avoid_sys_clone.patch"        # posix_spawn: fork() instead of __clone
patch -Np1 -i "${BUILDROOT}/disable_ctype_headers.patch"  # drop iswalpha/… decls (no table regen)
patch -Np1 -i "${BUILDROOT}/skip-pic-crt.patch"           # amd64: skip Scrt1.o/rcrt1.o (tcc segfaults on -fPIC %rip crt)
patch -Np1 -i "${BUILDROOT}/drop-dynamic-crt.patch"       # amd64: drop _DYNAMIC lea from crt_arch.h (tcc asm segfault on weak+hidden %rip)
patch -Np1 -i "${BUILDROOT}/amd64-va-list.patch"          # amd64: define __builtin_va_list via tcc's SysV __va_list_struct
patch -Np1 -i "${BUILDROOT}/amd64-syscall-arch.patch"     # amd64: rewrite __syscall4/5/6 — tcc-0.9.27 can't do GCC `register long r10 __asm__("r10")`

# meslibc/tcc cannot regenerate the ctype tables or iconv, and tcc has no _Complex — drop the consumers
# exactly as live-bootstrap pass1 does (these pair with disable_ctype_headers.patch):
rm src/ctype/iswalpha.c src/ctype/iswalnum.c src/ctype/iswctype.c src/ctype/towctrans.c
rm include/iconv.h src/locale/iconv.c src/locale/iconv_close.c
rm -rf src/complex

# [amd64 asm-rm] tcc-0.9.27's integrated assembler can't handle musl's x86_64 SSE math/fenv/setjmp .s
# (unknown opcodes e.g. stmxcsr/ldmxcsr, or SIGSEGV on others); tcc-musl2 has the IDENTICAL assembler
# limits.  Portable C fallbacks exist for all of them, so remove the asm and let musl build the C
# versions — correctness over speed, exactly right for a bootstrap libc.  KEEP core setjmp/x86_64/setjmp.s
# + longjmp.s (they assemble fine and have NO C fallback); only sigsetjmp.s fails and has a C fallback.
rm -f src/math/x86_64/*.s src/fenv/x86_64/*.s src/signal/x86_64/sigsetjmp.s

# --- configure: CC=tcc-musl2; --host=x86_64 is the amd64 adaptation.  static only; install layout baked
#     to /usr, physically redirected via DESTDIR below. ---
CC="${CC_MUSL2}" ./configure \
    --host=x86_64 \
    --disable-shared \
    --prefix=/usr \
    --libdir=/usr/lib \
    --includedir=/usr/include

# --- compile + install.  CROSS_COMPILE= blanks configure's x86_64- prefix on AR/RANLIB; AR="tcc-musl2 -ar"
#     / RANLIB=true because no binutils exists yet; CFLAGS=-DSYSCALL_NO_TLS matches live-bootstrap (errno
#     without TLS in the early/tcc context).  NO -march/-O/gcc-isms (tcc would reject them).  CC is
#     tcc-musl2 directly (no retry wrapper — it does not lottery). ---
make CROSS_COMPILE= CC="${CC_MUSL2}" AR="tcc-musl2 -ar" RANLIB=true CFLAGS="-DSYSCALL_NO_TLS -w"
rm -rf "${OUTPUT_DIR}/usr"
make CROSS_COMPILE= CC="${CC_MUSL2}" AR="tcc-musl2 -ar" RANLIB=true CFLAGS="-DSYSCALL_NO_TLS -w" \
     DESTDIR="${OUTPUT_DIR}" install

###########################################################################
# §SYSROOT — CLEAN SINGLE-WRITER MUSL SYSROOT (bedrock anti-pollution)
# Downstream rungs (s4 fixed-point gate, R5 binutils) run in a sandbox whose /usr is a MERGED hardlink
# farm shared with the glibc-linked shell tools (bash/coreutils/sed/grep/tar/gzip/gawk-bootstrap).  Those
# tools carry a `glibc` runtime_dep whose outputs ALSO include usr/include/** and usr/lib/libc.a — the
# SAME paths this musl installs above.  minimal's rootfs overlay is an UNORDERED hash-set materialized
# with FIRST-writer-wins collision handling (common::hardlink_dir_contents skips AlreadyExists), so at
# /usr/include/stdio.h and /usr/lib/libc.a the winner (musl vs glibc) is a nondeterministic per-build
# coin-flip.  When glibc wins, tcc-0.9.27 chokes on glibc's stdio.h ("invalid type") / links the wrong
# libc.  Fix: publish a byte-identical COPY of this musl at a path NOTHING else writes, so the downstream
# rungs have a deterministic clean tree to point -nostdinc / explicit-crt+libc at.  $OUTPUT_DIR/usr here
# is R4b's OWN install (pure musl — the glibc merge happens only in the CONSUMER sandbox), so the copy is
# guaranteed clean.
###########################################################################
SYSROOT="${OUTPUT_DIR}/usr/lib/musl-bedrock"
mkdir -p "${SYSROOT}/lib"
cp -a "${OUTPUT_DIR}/usr/include" "${SYSROOT}/include"
cp -a "${OUTPUT_DIR}"/usr/lib/*.a "${OUTPUT_DIR}"/usr/lib/*.o "${SYSROOT}/lib/"

#########################################################################
# FLOAT + printf CORRECTNESS GATE  [FAIL-SHUT — no re-roll]
# WHY IT SURVIVES THE R4a→R4b SWAP: the R4a mes-tcc, under the arena lottery, SOMETIMES emitted fmt_fp's
# `long double` constants (0x1p28 at src/stdio/vfprintf.c:268) as ZERO in .data — an rc=0, SILENT
# miscompile (every %f/%g/%Lf prints "0.00").  tcc-musl2 is DETERMINISTIC, so this gate should PASS
# `3.75 2.0` every time.  We KEEP it as a fail-shut regression guard: if it EVER fails, that is a REAL
# deterministic codegen/libc bug in tcc-musl2 or the musl source (a genuine trust defect), NOT a lottery
# — so we exit 1 HARD as a plain BuildScriptFailed (no MesccArenaLottery re-roll marker; a re-enqueue
# would reproduce the SAME failure).  Compile+link+RUN a tiny printf against the JUST-BUILT musl, exactly
# as a static musl-cc would (-nostdlib -static crt1 crti <obj> libc.a libtcc1.a libc.a crtn.o).
#########################################################################
GATEDIR="${BUILDROOT}/float-gate"
rm -rf "${GATEDIR}"
mkdir -p "${GATEDIR}"
MUSL_LIB="${OUTPUT_DIR}/usr/lib"
MUSL_INC="${OUTPUT_DIR}/usr/include"

cat > "${GATEDIR}/floatgate.c" <<'FLOATGATE'
#include <stdio.h>
int main(void){ volatile double a=1.5,b=2.25; long double c=0x1p28L; printf("%.2f %.1Lf\n", a+b, (long double)(c/0x1p27L)); return 0; }
FLOATGATE

GATE_OUT="<compile-or-link-failed>"
# Run the gate steps WITHOUT set -e so a failure yields a clean diagnostic + hard exit 1 (not a bare abort).
set +e
# compile against the just-built musl headers in the same -nostdinc freestanding mode the libc built in
"${CC_MUSL2}" -c -nostdinc -I "${MUSL_INC}" -DSYSCALL_NO_TLS \
    "${GATEDIR}/floatgate.c" -o "${GATEDIR}/floatgate.o"
gcrc=$?
# link exactly like static musl-cc: crt1 crti <obj> libc.a libtcc1.a libc.a crtn.o (libc.a repeated so
# libtcc1<->libc back-references resolve without --start-group, which tcc lacks)
"${CC_MUSL2}" -nostdlib -static \
    "${MUSL_LIB}/crt1.o" "${MUSL_LIB}/crti.o" \
    "${GATEDIR}/floatgate.o" \
    "${MUSL_LIB}/libc.a" "${LIBTCC1}" "${MUSL_LIB}/libc.a" \
    "${MUSL_LIB}/crtn.o" \
    -o "${GATEDIR}/floatgate"
glrc=$?
if [ ${gcrc} -eq 0 ] && [ ${glrc} -eq 0 ]; then
  GATE_OUT="$(timeout 15 "${GATEDIR}/floatgate")" || GATE_OUT="<runtime-crash-or-timeout>"
fi
set -e

if [ "${GATE_OUT}" = "3.75 2.0" ]; then
  echo "R4b-FLOAT-GATE: PASS (got '${GATE_OUT}')" >&2
else
  # FAIL-SHUT: deterministic bug, NOT a lottery.  Plain BuildScriptFailed — NO mes-m2/rc=139 marker.
  echo "R4b-FLOAT-GATE: FAIL (compile-rc=${gcrc} link-rc=${glrc} got '${GATE_OUT}', want '3.75 2.0')" >&2
  echo "R4b build FAILED: the float/printf correctness gate did not pass.  tcc-musl2 is DETERMINISTIC, so" >&2
  echo "  this is a REAL codegen/libc defect (NOT the mes arena lottery) — a re-enqueue will reproduce it." >&2
  echo "  Investigate tcc-musl2 fmt_fp long-double .data emission / the musl source, do NOT re-roll." >&2
  exit 1
fi

###########################################################################
# BYTE-IDENTITY SEAL — record-at-pin-time.
# UNLIKE R4a (where the mes-tcc lottery made the build non-deterministic and forced the seal to a
# non-fatal warning), R4b IS DETERMINISTIC: tcc-musl2 has no allocator lottery, so byte-identity across
# rebuilds is a REAL reproducibility invariant and is MEANINGFUL again.  For the first (capture) build no
# reference exists yet, so stage0.answers ships as an UNPINNED placeholder and we only RECORD.  After the
# operator captures the real hashes from this green build into stage0.answers, every rebuild MUST match;
# flip SEAL_FATAL=1 (below) to PROMOTE the seal to fail-shut once pinned.
# Paths in stage0.answers are RELATIVE to $OUTPUT_DIR, so we check from there.
###########################################################################
SEAL_FATAL="${SEAL_FATAL:-0}"   # one-line knob: set to 1 once stage0.answers is pinned to make a mismatch fatal
cd "${OUTPUT_DIR}"
if head -1 "${BUILDROOT}/stage0.answers" 2>/dev/null | grep -q '^# UNPINNED'; then
  echo "R4b byte-identity seal: NOT YET PINNED (deterministic build) — record stage0.answers from this roll:" >&2
  echo "  sha256sum usr/lib/libc.a usr/lib/*.o  (run in \$OUTPUT_DIR), then drop the '# UNPINNED' sentinel." >&2
else
  if sha256sum -c "${BUILDROOT}/stage0.answers"; then
    echo "R4b byte-identity seal: MATCH (deterministic build reproduced the pinned reference)." >&2
  else
    echo "WARNING: R4b byte-identity seal MISMATCH." >&2
    echo "  R4b is DETERMINISTIC, so a mismatch against a PINNED reference is a REAL reproducibility failure." >&2
    if [ "${SEAL_FATAL}" = 1 ]; then
      echo "  SEAL_FATAL=1 -> failing the build." >&2
      exit 1
    fi
    echo "  SEAL_FATAL=0 (capture window) -> non-fatal; re-capture stage0.answers, then set SEAL_FATAL=1." >&2
  fi
fi

###########################################################################
# §D STAGING: every output went to DESTDIR=$OUTPUT_DIR, so build.ncl's `outputs` globs already match the
# on-disk tree:  usr/lib/libc.a · usr/lib/*.o (crt1/crti/crtn) · usr/lib/*.a (incl. empty stubs) ·
# usr/include/**  (musl headers)
###########################################################################
