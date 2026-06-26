#!/usr/bin/env bash
# musl-crt-diag v19 — validate neg-float-const v3 (ROOT -0.0-bits fix) breaks the NaN fixed point.
# THE check (load-bearing): build `double neg(double x){return -x;}` with the freshly-built R3 tcc-0.9.27
# and dump the negate CONSTANT — must be 8000000000000000 (-0.0), NOT fff8.. (the NaN that poisoned every
# negation, compile-time AND runtime). Plus: exp_data/math compile, and make -k count (expect ~8 left:
# pow_data/float×negint + towupper×6, which are SEPARATE facets). asm-rm carried.
set +e
set -u
TCC=/usr/bin/tcc
VERSION="${MINIMAL_ARG_VERSION:-1.1.24}"
SRC="musl-${VERSION}"; BUILDROOT="$(pwd)"
OUTROOT=/build/output/usr/share/musl-crt-diag; WORK=/build/diag
mkdir -p "$OUTROOT" "$WORK"; MANIFEST="$OUTROOT/MANIFEST.txt"
emit(){ echo "$1"; echo "$1" >> "$WORK/rows.txt"; }
emit "DIAG-INFO musl-crt-diag v19 ROOT-FIX-VALIDATE — $("$TCC" -version 2>&1 | head -1)"
tar -xf "${SRC}.tar.gz" 2>/dev/null; cd "${SRC}" || { emit FATAL; exit 0; }
for p in makefile madvise_preserve_errno avoid_sys_clone disable_ctype_headers skip-pic-crt drop-dynamic-crt amd64-va-list amd64-syscall-arch; do
  patch -Np1 -i "${BUILDROOT}/${p}.patch" >/dev/null 2>&1
done
rm src/ctype/iswalpha.c src/ctype/iswalnum.c src/ctype/iswctype.c src/ctype/towctrans.c 2>/dev/null
rm include/iconv.h src/locale/iconv.c src/locale/iconv_close.c 2>/dev/null; rm -rf src/complex 2>/dev/null
rm src/math/x86_64/*.s src/fenv/x86_64/*.s src/signal/x86_64/sigsetjmp.s 2>/dev/null
CC=tcc ./configure --host=x86_64 --disable-shared --prefix=/usr --libdir=/usr/lib --includedir=/usr/include >/dev/null 2>&1
make obj/include/bits/alltypes.h obj/include/bits/syscall.h >/dev/null 2>&1
FULL="-std=c99 -nostdinc -ffreestanding -fexcess-precision=standard -frounding-math -Wa,--noexecstack -D_XOPEN_SOURCE=700 -I./arch/x86_64 -I./arch/generic -Iobj/src/internal -I./src/include -I./src/internal -Iobj/include -I./include -Os -pipe -fomit-frame-pointer -fno-unwind-tables -fno-asynchronous-unwind-tables -ffunction-sections -fdata-sections -DSYSCALL_NO_TLS -fno-stack-protector"
cls(){ rc=$1; if [ "$rc" = 0 ]; then echo OK; elif [ "$rc" -gt 128 ] 2>/dev/null; then echo "CRASH(rc=$rc)"; else echo "err(rc=$rc)"; fi; }
try(){ "$TCC" $FULL -c -o "$WORK/t.o" "$1" >"$WORK/t.err" 2>&1; cls $?; }

# THE fixed-point-break check: the runtime negate constant must be -0.0 (8000..), not NaN (fff8..).
printf 'double neg(double x){return -x;}\n' > "$WORK/neg.c"
"$TCC" $FULL -c -o "$WORK/neg.o" "$WORK/neg.c" >/dev/null 2>&1
emit "DIAG-ROOT runtime -0.0 negate const (want ...00 00 80 / 80 00..; NaN= f8 ff):"
od -An -tx1 "$WORK/neg.o" 2>/dev/null | grep -iE "00 00 00 80|f8 ff|00 80" | head -3 | while IFS= read -r l; do emit "DIAG-ROOT  $l"; done
emit "DIAG-ROOT  NaN(f8ff) bytes present = $(od -An -tx1 "$WORK/neg.o" 2>/dev/null | grep -c 'f8 ff')  (want 0)"
# compile-time const negate value too
printf 'double g[2]={-1.5,-0.5};\n' > "$WORK/v.c"; "$TCC" $FULL -c -o "$WORK/v.o" "$WORK/v.c" >/dev/null 2>&1
emit "DIAG-ROOT  const {-1.5,-0.5}: f8bf(ok)=$(od -An -tx1 "$WORK/v.o" 2>/dev/null|grep -c 'f8 bf')  f8ff(NaN)=$(od -An -tx1 "$WORK/v.o" 2>/dev/null|grep -c 'f8 ff')"

emit "DIAG-NEG  double a[]={-1.5} -> $(printf 'double a[]={-1.5};\n'>"$WORK/n.c"; try "$WORK/n.c")"
for f in src/math/exp_data.c src/math/__cosl.c src/math/acos.c; do [ -f "$f" ] && emit "DIAG-MATH $(basename $f) -> $(try "$f")"; done

emit "DIAG-INFO ===== make -k full count ====="
make -k CROSS_COMPILE= AR="tcc -ar" RANLIB=true CFLAGS="-DSYSCALL_NO_TLS" >"$WORK/makek.log" 2>&1
NFAIL=$(grep -aoE "obj/[^ ]+\.o] (Segmentation fault|Error)" "$WORK/makek.log" 2>/dev/null | sed 's/].*//' | sort -u | wc -l)
emit "DIAG-VALID make -k distinct-fails=$NFAIL  (was 9; root-fix shouldn't regress; pow_data/towupper are separate)  libc.a=$( [ -f lib/libc.a ] && echo PRESENT || echo ABSENT )"
grep -aoE "obj/src/[a-z0-9_]+/[^ ]+\.o] (Segmentation fault|Error)" "$WORK/makek.log" 2>/dev/null | sed -E 's#obj/src/([a-z0-9_]+)/.*#\1#' | sort | uniq -c | sort -rn | while IFS= read -r l; do emit "DIAG-VALID   $l"; done

cp "$WORK/rows.txt" "$OUTROOT/rows.txt.log" 2>/dev/null
cp "$WORK/makek.log" "$OUTROOT/makek.log" 2>/dev/null
cp "$TCC" "$OUTROOT/tcc-0.9.27" 2>/dev/null
{
  echo "============ musl-crt-diag v19 ROOT-FIX-VALIDATE ============"
  grep -E "DIAG-ROOT|DIAG-NEG|DIAG-MATH|DIAG-VALID" "$WORK/rows.txt" 2>/dev/null
  echo "READ: DIAG-ROOT NaN-bytes=0 => the -0.0 fixed point is BROKEN (negation correct compile+runtime)."
  echo "      Remaining fails = pow_data(float×negint) + towupper×6 — SEPARATE facets, next."
  echo "============================================================"
} | tee "$MANIFEST"
exit 0
