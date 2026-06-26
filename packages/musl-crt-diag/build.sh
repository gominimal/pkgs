#!/usr/bin/env bash
# musl-crt-diag v17 — VALIDATE the neg-float-const R3 fix end-to-end. Root cause (found via a local
# amd64-container tcc harness): our mes-chain tcc-0.9.26 miscompiles tcc-0.9.27's unary-minus-on-float-
# CONSTANT path, so a negated float literal in a static initializer (musl math coefficient tables) is
# wrongly rejected "initializer element is not constant" -> SIGSEGV (the 48-file math wall). R3 now carries
# neg-float-const.patch (direct-negate the constant). This probe builds against the PATCHED R3 and checks:
#   (A) exp_data.c + a sample of the 48 math crashers compile (were CRASH).
#   (B) make -k full count: expect ~57 -> ~9 (math cluster cleared; only regex/ctype/string/signal/fenv left).
# set +e, exit 0, OutputData.
set +e
set -u
TCC=/usr/bin/tcc
VERSION="${MINIMAL_ARG_VERSION:-1.1.24}"
SRC="musl-${VERSION}"; BUILDROOT="$(pwd)"
OUTROOT=/build/output/usr/share/musl-crt-diag; WORK=/build/diag
mkdir -p "$OUTROOT" "$WORK"; MANIFEST="$OUTROOT/MANIFEST.txt"
emit(){ echo "$1"; echo "$1" >> "$WORK/rows.txt"; }
emit "DIAG-INFO musl-crt-diag v17 VALIDATE-NEGFIX — $("$TCC" -version 2>&1 | head -1)"
tar -xf "${SRC}.tar.gz" 2>/dev/null; cd "${SRC}" || { emit FATAL; exit 0; }
for p in makefile madvise_preserve_errno avoid_sys_clone disable_ctype_headers skip-pic-crt drop-dynamic-crt amd64-va-list amd64-syscall-arch; do
  patch -Np1 -i "${BUILDROOT}/${p}.patch" >/dev/null 2>&1
done
rm src/ctype/iswalpha.c src/ctype/iswalnum.c src/ctype/iswctype.c src/ctype/towctrans.c 2>/dev/null
rm include/iconv.h src/locale/iconv.c src/locale/iconv_close.c 2>/dev/null; rm -rf src/complex 2>/dev/null
CC=tcc ./configure --host=x86_64 --disable-shared --prefix=/usr --libdir=/usr/lib --includedir=/usr/include >/dev/null 2>&1
make obj/include/bits/alltypes.h obj/include/bits/syscall.h >/dev/null 2>&1
FULL="-std=c99 -nostdinc -ffreestanding -fexcess-precision=standard -frounding-math -Wa,--noexecstack -D_XOPEN_SOURCE=700 -I./arch/x86_64 -I./arch/generic -Iobj/src/internal -I./src/include -I./src/internal -Iobj/include -I./include -Os -pipe -fomit-frame-pointer -fno-unwind-tables -fno-asynchronous-unwind-tables -ffunction-sections -fdata-sections -DSYSCALL_NO_TLS -fno-stack-protector"
cls(){ rc=$1; if [ "$rc" = 0 ]; then echo OK; elif [ "$rc" -gt 128 ] 2>/dev/null; then echo "CRASH(rc=$rc)"; else echo "err(rc=$rc)"; fi; }
try(){ "$TCC" $FULL -c -o "$WORK/t.o" "$1" >"$WORK/t.err" 2>&1; cls $?; }
# 1-line repro first (the smoking gun)
printf 'double a[]={-1.5};\n' > "$WORK/neg.c"
emit "DIAG-NEG  one-liner double a[]={-1.5} -> $(try "$WORK/neg.c")   [was CRASH]"

emit "DIAG-INFO ===== (A) math files that crashed pre-fix ====="
for f in src/math/exp_data.c src/math/pow_data.c src/math/log_data.c src/math/log2_data.c src/math/__cosl.c src/math/acos.c src/math/asin.c src/math/erf.c src/math/j0.c src/math/lgamma_r.c src/math/expm1.c; do
  [ -f "$f" ] && emit "DIAG-MATH $(basename $f) -> $(try "$f")"
done

emit "DIAG-INFO ===== (B) make -k full count ====="
make -k CROSS_COMPILE= AR="tcc -ar" RANLIB=true CFLAGS="-DSYSCALL_NO_TLS" >"$WORK/makek.log" 2>&1
NFAIL=$(grep -aoE "obj/[^ ]+\.o] (Segmentation fault|Error)" "$WORK/makek.log" 2>/dev/null | sed 's/].*//' | sort -u | wc -l)
emit "DIAG-VALID make -k distinct-fails=$NFAIL  (was 57; expect ~9 if math cleared)  libc.a=$( [ -f lib/libc.a ] && echo PRESENT:$(wc -c <lib/libc.a)B || echo ABSENT )"
emit "DIAG-VALID remaining fails by subsystem:"
grep -aoE "obj/src/[a-z0-9_]+/[^ ]+\.o] (Segmentation fault|Error)" "$WORK/makek.log" 2>/dev/null | sed -E 's#obj/src/([a-z0-9_]+)/.*#\1#' | sort | uniq -c | sort -rn | while IFS= read -r l; do emit "DIAG-VALID   $l"; done
emit "DIAG-VALID remaining files:"
grep -aoE "obj/src/[a-z0-9_/]+\.o] (Segmentation fault|Error)" "$WORK/makek.log" 2>/dev/null | sed 's/].*//' | sort -u | head -15 | while IFS= read -r l; do emit "DIAG-FAIL $l"; done

cp "$WORK/rows.txt" "$OUTROOT/rows.txt.log" 2>/dev/null
cp "$WORK/makek.log" "$OUTROOT/makek.log" 2>/dev/null
cp "$TCC" "$OUTROOT/tcc-0.9.27" 2>/dev/null
{
  echo "============ musl-crt-diag v17 VALIDATE-NEGFIX ============"
  grep -E "DIAG-NEG|DIAG-MATH|DIAG-VALID|DIAG-FAIL" "$WORK/rows.txt" 2>/dev/null
  echo "READ: DIAG-NEG OK + math all OK + fails 57->~9 => the neg-float-const R3 fix WORKS (tcc-0.9.26"
  echo "      compiled the patch correctly). Remaining ~9 = the non-math stragglers, next to chase."
  echo "=========================================================="
} | tee "$MANIFEST"
exit 0
