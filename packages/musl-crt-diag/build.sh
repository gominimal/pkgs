#!/usr/bin/env bash
# musl-crt-diag v18 — validate neg-float-const v2 (XOR sign-flip) on the MES-built tcc + the asm-rm.
# v1 (direct -c.d) emitted NaN (tcc-0.9.26 miscompiles FP negate); v2 flips the IEEE sign bit via integer
# XOR. The load-bearing check is VALUE-correctness (not just "compiles"): dump the bytes of {-1.5} and
# confirm 0xBFF8.. not 0xFFF8.. (NaN). Plus: pow_data (float * -2.0) must now COMPILE (proves finite values
# -> ieee_finite passes -> fold works). And rm the x86_64/*.s asm tcc can't assemble (C fallbacks build).
set +e
set -u
TCC=/usr/bin/tcc
VERSION="${MINIMAL_ARG_VERSION:-1.1.24}"
SRC="musl-${VERSION}"; BUILDROOT="$(pwd)"
OUTROOT=/build/output/usr/share/musl-crt-diag; WORK=/build/diag
mkdir -p "$OUTROOT" "$WORK"; MANIFEST="$OUTROOT/MANIFEST.txt"
emit(){ echo "$1"; echo "$1" >> "$WORK/rows.txt"; }
emit "DIAG-INFO musl-crt-diag v18 VALIDATE-XOR — $("$TCC" -version 2>&1 | head -1)"
tar -xf "${SRC}.tar.gz" 2>/dev/null; cd "${SRC}" || { emit FATAL; exit 0; }
for p in makefile madvise_preserve_errno avoid_sys_clone disable_ctype_headers skip-pic-crt drop-dynamic-crt amd64-va-list amd64-syscall-arch; do
  patch -Np1 -i "${BUILDROOT}/${p}.patch" >/dev/null 2>&1
done
rm src/ctype/iswalpha.c src/ctype/iswalnum.c src/ctype/iswctype.c src/ctype/towctrans.c 2>/dev/null
rm include/iconv.h src/locale/iconv.c src/locale/iconv_close.c 2>/dev/null; rm -rf src/complex 2>/dev/null
# [amd64 asm-rm] tcc can't assemble the x86_64 SSE math/fenv .s (unknown opcodes / segfaults); rm -> C fallbacks build.
rm src/math/x86_64/*.s src/fenv/x86_64/*.s 2>/dev/null; emit "DIAG-INFO rm'd x86_64 math/fenv asm (use C fallbacks)"
CC=tcc ./configure --host=x86_64 --disable-shared --prefix=/usr --libdir=/usr/lib --includedir=/usr/include >/dev/null 2>&1
make obj/include/bits/alltypes.h obj/include/bits/syscall.h >/dev/null 2>&1
FULL="-std=c99 -nostdinc -ffreestanding -fexcess-precision=standard -frounding-math -Wa,--noexecstack -D_XOPEN_SOURCE=700 -I./arch/x86_64 -I./arch/generic -Iobj/src/internal -I./src/include -I./src/internal -Iobj/include -I./include -Os -pipe -fomit-frame-pointer -fno-unwind-tables -fno-asynchronous-unwind-tables -ffunction-sections -fdata-sections -DSYSCALL_NO_TLS -fno-stack-protector"
cls(){ rc=$1; if [ "$rc" = 0 ]; then echo OK; elif [ "$rc" -gt 128 ] 2>/dev/null; then echo "CRASH(rc=$rc)"; else echo "err(rc=$rc)"; fi; }
try(){ "$TCC" $FULL -c -o "$WORK/t.o" "$1" >"$WORK/t.err" 2>&1; cls $?; }

# VALUE check: {-1.5} must be 0xBFF8.. not 0xFFF8.. (NaN). dump .data bytes via od.
printf 'double g[2]={-1.5, -0.5};\n' > "$WORK/v.c"
"$TCC" $FULL -c -o "$WORK/v.o" "$WORK/v.c" >/dev/null 2>&1
emit "DIAG-VALUE {-1.5,-0.5} .o data bytes (expect ...f8 bf / ...e0 bf; NaN would be ...f8 ff):"
od -An -tx1 "$WORK/v.o" 2>/dev/null | grep -iE "f8 bf|f8 ff|e0 bf" | head -2 | while IFS= read -r l; do emit "DIAG-VALUE  $l"; done
emit "DIAG-VALUE  grep f8bf(correct)=$(od -An -tx1 "$WORK/v.o" 2>/dev/null | grep -c 'f8 bf')  f8ff(NaN)=$(od -An -tx1 "$WORK/v.o" 2>/dev/null | grep -c 'f8 ff')"

# FUNCTIONAL: pow_data (float * -2.0) must compile now (finite values -> fold works)
emit "DIAG-NEG  double a[]={-1.5} -> $(printf 'double a[]={-1.5};\n' > "$WORK/n.c"; try "$WORK/n.c")"
emit "DIAG-NEG  double a[]={0x1.5p-2 * -2.0} -> $(printf 'double a[]={0x1.5p-2 * -2.0};\n' > "$WORK/m.c"; try "$WORK/m.c")"
for f in src/math/pow_data.c src/math/powf_data.c src/math/exp_data.c; do [ -f "$f" ] && emit "DIAG-POW $(basename $f) -> $(try "$f")"; done

emit "DIAG-INFO ===== make -k full count ====="
make -k CROSS_COMPILE= AR="tcc -ar" RANLIB=true CFLAGS="-DSYSCALL_NO_TLS" >"$WORK/makek.log" 2>&1
NFAIL=$(grep -aoE "obj/[^ ]+\.o] (Segmentation fault|Error)" "$WORK/makek.log" 2>/dev/null | sed 's/].*//' | sort -u | wc -l)
emit "DIAG-VALID make -k distinct-fails=$NFAIL  (was 20; expect ~6-8: regex/ctype/string/signal)  libc.a=$( [ -f lib/libc.a ] && echo PRESENT:$(wc -c <lib/libc.a)B || echo ABSENT )"
grep -aoE "obj/src/[a-z0-9_]+/[^ ]+\.o] (Segmentation fault|Error)" "$WORK/makek.log" 2>/dev/null | sed -E 's#obj/src/([a-z0-9_]+)/.*#\1#' | sort | uniq -c | sort -rn | while IFS= read -r l; do emit "DIAG-VALID   $l"; done
grep -aoE "obj/src/[a-z0-9_/]+\.o] (Segmentation fault|Error)" "$WORK/makek.log" 2>/dev/null | sed 's/].*//' | sort -u | head -12 | while IFS= read -r l; do emit "DIAG-FAIL $l"; done

cp "$WORK/rows.txt" "$OUTROOT/rows.txt.log" 2>/dev/null
cp "$WORK/makek.log" "$OUTROOT/makek.log" 2>/dev/null
cp "$TCC" "$OUTROOT/tcc-0.9.27" 2>/dev/null
{
  echo "============ musl-crt-diag v18 VALIDATE-XOR ============"
  grep -E "DIAG-VALUE|DIAG-NEG|DIAG-POW|DIAG-VALID|DIAG-FAIL" "$WORK/rows.txt" 2>/dev/null
  echo "READ: f8bf(correct) count>0 & f8ff(NaN)=0 + pow_data OK + fails 20->~6 => XOR fix CORRECT + asm-rm works."
  echo "======================================================="
} | tee "$MANIFEST"
exit 0
