#!/usr/bin/env bash
# musl-crt-diag v11 — SCOPE the R4 tail. The [static] tcc fix (R3) worked: syscall.h compiles, breadth
# 23/24, make went from crash-on-file-1 to ~40 files deep before SIGSEGV on src/ctype/iswlower.c — a
# TRIVIAL file (`return towupper(wc)!=wc;`, no exotic construct) while structurally-identical iswdigit.c
# compiled. Prime suspect: the ~50% arena/ASLR LOTTERY now showing in tcc-0.9.27 (would make R4's
# ~1900-file make rarely complete). Two questions, one cycle:
#   (A) LOTTERY vs DETERMINISTIC — compile iswlower.c / regcomp.c / isdigit.c(control) 8x each; count crashes.
#       ~mixed => lottery (cure = per-file retry); 8/8 => a real construct (find+fix).
#   (B) FULL SCOPE — `make -k` (keep-going) compiles ALL files; report objects built + EVERY failing target.
#       Tail = a handful of named files => tractable; tail = many scattered/varying => lottery-dominated.
set +e
set -u
TCC=/usr/bin/tcc
VERSION="${MINIMAL_ARG_VERSION:-1.1.24}"
SRC="musl-${VERSION}"; BUILDROOT="$(pwd)"
OUTROOT=/build/output/usr/share/musl-crt-diag; WORK=/build/diag
mkdir -p "$OUTROOT" "$WORK"; MANIFEST="$OUTROOT/MANIFEST.txt"
emit(){ echo "$1"; echo "$1" >> "$WORK/rows.txt"; }
emit "DIAG-INFO musl-crt-diag v11 SCOPE-TAIL — $("$TCC" -version 2>&1 | head -1)"
tar -xf "${SRC}.tar.gz" 2>/dev/null; cd "${SRC}" || { emit FATAL; exit 0; }
for p in makefile madvise_preserve_errno avoid_sys_clone disable_ctype_headers skip-pic-crt drop-dynamic-crt amd64-va-list; do
  patch -Np1 -i "${BUILDROOT}/${p}.patch" >/dev/null 2>&1
done
rm src/ctype/iswalpha.c src/ctype/iswalnum.c src/ctype/iswctype.c src/ctype/towctrans.c 2>/dev/null
rm include/iconv.h src/locale/iconv.c src/locale/iconv_close.c 2>/dev/null; rm -rf src/complex 2>/dev/null
CC=tcc ./configure --host=x86_64 --disable-shared --prefix=/usr --libdir=/usr/lib --includedir=/usr/include >/dev/null 2>&1
make obj/include/bits/alltypes.h obj/include/bits/syscall.h >/dev/null 2>&1
FULL="-std=c99 -nostdinc -ffreestanding -fexcess-precision=standard -frounding-math -Wa,--noexecstack -D_XOPEN_SOURCE=700 -I./arch/x86_64 -I./arch/generic -Iobj/src/internal -I./src/include -I./src/internal -Iobj/include -I./include -Os -pipe -fomit-frame-pointer -fno-unwind-tables -fno-asynchronous-unwind-tables -ffunction-sections -fdata-sections -DSYSCALL_NO_TLS -fno-stack-protector"

# (A) lottery vs deterministic — 8 reps each
emit "DIAG-INFO ===== (A) repeat-compile (lottery vs deterministic) ====="
rep(){ f="$1"; c=0; for i in 1 2 3 4 5 6 7 8; do "$TCC" $FULL -c -o "$WORK/r.o" "$f" >/dev/null 2>&1; [ "$?" -gt 128 ] && c=$((c+1)); done; echo "$c"; }
for f in src/ctype/iswlower.c src/regex/regcomp.c src/ctype/isdigit.c src/ctype/iswlower.c; do
  [ -f "$f" ] && emit "DIAG-REP $(basename $f) crashes=$(rep "$f")/8"
done

# (B) full scope — make -k, list every failing target
emit "DIAG-INFO ===== (B) make -k full scope ====="
make -k CROSS_COMPILE= AR="tcc -ar" RANLIB=true CFLAGS="-DSYSCALL_NO_TLS" >"$WORK/makek.log" 2>&1; MRC=$?
NOBJ=$(find obj -name '*.o' 2>/dev/null | wc -l)
NSEG=$(grep -acE "Segmentation fault|signal" "$WORK/makek.log")
emit "DIAG-SCOPE make -k rc=$MRC  objects_built=$NOBJ  segfault_lines=$NSEG  libc.a=$( [ -f lib/libc.a ] && echo PRESENT || echo ABSENT )"
emit "DIAG-SCOPE every failing target:"
grep -aoE "obj/[^ ]+\.o] (Segmentation fault|Error)" "$WORK/makek.log" 2>/dev/null | sed 's/].*//' | sort -u | while IFS= read -r t; do emit "DIAG-FAIL $t"; done
emit "DIAG-SCOPE total distinct failing targets = $(grep -aoE 'obj/[^ ]+\.o] (Segmentation fault|Error)' "$WORK/makek.log" 2>/dev/null | sed 's/].*//' | sort -u | wc -l)"

cp "$WORK/rows.txt" "$OUTROOT/rows.txt.log" 2>/dev/null
cp "$WORK/makek.log" "$OUTROOT/makek.log" 2>/dev/null
cp "$TCC" "$OUTROOT/tcc-0.9.27" 2>/dev/null
{
  echo "============ musl-crt-diag v11 SCOPE-TAIL ============"
  grep -E "DIAG-REP|DIAG-SCOPE|DIAG-FAIL" "$WORK/rows.txt" 2>/dev/null
  echo "READ: DIAG-REP mixed (e.g. 3-5/8) => LOTTERY (cure=retry, not a code fix). 8/8 => construct."
  echo "      DIAG-FAIL list = the complete R4 tail. Few named => tractable; many/varying => lottery-bound."
  echo "====================================================="
} | tee "$MANIFEST"
exit 0
