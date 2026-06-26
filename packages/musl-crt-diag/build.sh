#!/usr/bin/env bash
# musl-crt-diag v12 — OVERNIGHT: (A) validate the register-var fix in the FULL build, (B) pin the math
# cluster construct. v11 scoped the R4 tail to 88 deterministic amd64-codegen crashers: ~20 syscall
# wrappers (r8/r9 register-vars) + 48 math/ (an amd64 x86_64-gen.c FP-codegen defect; live-bootstrap is
# i386-only so no upstream fix). This probe:
#   (A) apply amd64-syscall-arch.patch (s4/s5/s6 register-vars -> in-asm movq, F2 form validated in v7)
#       then `make -k` and report the NEW failing count + per-subsystem breakdown. Expect linux/network/
#       thread/mman syscall-users to CLEAR (~88 -> ~68), confirming the register-var fix end-to-end.
#   (B) MATH build-down — isolate hex-float / long-double / hex-long-double / union-pun / aggregate-init,
#       + build-down a real pure-data math file (exp_data.c: -E ok? compile .i?). Pins which FP construct
#       crashes tcc's amd64 backend, so next session crafts the fix (likely tcc x86_64-gen.c -> re-seal R3).
# set +e, never aborts, exit 0, OutputData. NOTE: the movq form is COMPILE-validated; its runtime arg
# marshalling (g-input aliasing vs the scratch movqs) needs a runtime check before R4 SEAL — see memory.
set +e
set -u
TCC=/usr/bin/tcc
VERSION="${MINIMAL_ARG_VERSION:-1.1.24}"
SRC="musl-${VERSION}"; BUILDROOT="$(pwd)"
OUTROOT=/build/output/usr/share/musl-crt-diag; WORK=/build/diag
mkdir -p "$OUTROOT" "$WORK"; MANIFEST="$OUTROOT/MANIFEST.txt"
emit(){ echo "$1"; echo "$1" >> "$WORK/rows.txt"; }
emit "DIAG-INFO musl-crt-diag v12 OVERNIGHT(syscall-fix+math-builddown) — $("$TCC" -version 2>&1 | head -1)"
tar -xf "${SRC}.tar.gz" 2>/dev/null; cd "${SRC}" || { emit FATAL; exit 0; }
for p in makefile madvise_preserve_errno avoid_sys_clone disable_ctype_headers skip-pic-crt drop-dynamic-crt amd64-va-list amd64-syscall-arch; do
  patch -Np1 -i "${BUILDROOT}/${p}.patch" >/dev/null 2>&1 && emit "DIAG-PATCH $p applied" || emit "DIAG-PATCH $p FAILED-TO-APPLY"
done
rm src/ctype/iswalpha.c src/ctype/iswalnum.c src/ctype/iswctype.c src/ctype/towctrans.c 2>/dev/null
rm include/iconv.h src/locale/iconv.c src/locale/iconv_close.c 2>/dev/null; rm -rf src/complex 2>/dev/null
CC=tcc ./configure --host=x86_64 --disable-shared --prefix=/usr --libdir=/usr/lib --includedir=/usr/include >/dev/null 2>&1
make obj/include/bits/alltypes.h obj/include/bits/syscall.h >/dev/null 2>&1
FULL="-std=c99 -nostdinc -ffreestanding -fexcess-precision=standard -frounding-math -Wa,--noexecstack -D_XOPEN_SOURCE=700 -I./arch/x86_64 -I./arch/generic -Iobj/src/internal -I./src/include -I./src/internal -Iobj/include -I./include -Os -pipe -fomit-frame-pointer -fno-unwind-tables -fno-asynchronous-unwind-tables -ffunction-sections -fdata-sections -DSYSCALL_NO_TLS -fno-stack-protector"
cls(){ rc=$1; if [ "$rc" = 0 ]; then echo OK; elif [ "$rc" -gt 128 ] 2>/dev/null; then echo "CRASH(rc=$rc)"; else echo "err(rc=$rc)"; fi; }
try(){ "$TCC" $FULL -c -o "$WORK/t.o" "$1" >"$WORK/t.err" 2>&1; cls $?; }

# (A) register-var fix end-to-end: make -k, new failing count + breakdown
emit "DIAG-INFO ===== (A) make -k WITH amd64-syscall-arch.patch ====="
make -k CROSS_COMPILE= AR="tcc -ar" RANLIB=true CFLAGS="-DSYSCALL_NO_TLS" >"$WORK/makek.log" 2>&1
NFAIL=$(grep -aoE "obj/[^ ]+\.o] (Segmentation fault|Error)" "$WORK/makek.log" 2>/dev/null | sed 's/].*//' | sort -u | wc -l)
emit "DIAG-SYSFIX make -k distinct-fails=$NFAIL  (was 88; expect ~68 if syscall cluster cleared)  libc.a=$( [ -f lib/libc.a ] && echo PRESENT || echo ABSENT )"
emit "DIAG-SYSFIX failing by subsystem:"
grep -aoE "obj/src/[a-z0-9_]+/[^ ]+\.o] (Segmentation fault|Error)" "$WORK/makek.log" 2>/dev/null | sed -E 's#obj/src/([a-z0-9_]+)/.*#\1#' | sort | uniq -c | sort -rn | while IFS= read -r l; do emit "DIAG-SYSFIX   $l"; done
emit "DIAG-SYSFIX linux/ still-failing (should be ~0 now):"
grep -aoE "obj/src/linux/[^ ]+\.o] (Segmentation fault|Error)" "$WORK/makek.log" 2>/dev/null | sed 's/].*//' | sort -u | head | while IFS= read -r l; do emit "DIAG-SYSFIX   $l"; done

# (B) MATH build-down — isolate the FP construct
emit "DIAG-INFO ===== (B) math FP construct build-down ====="
printf 'float f(void){return 0x1p-120f;}\n' > "$WORK/m_hexf.c"
printf 'double d(void){return 0x1.62e42fefa39efp-1;}\n' > "$WORK/m_hexd.c"
printf 'long double g(long double x){return x*x+1.0L;}\n' > "$WORK/m_ld.c"
printf 'long double h(void){return 0x8.0p-4L;}\n' > "$WORK/m_ldhex.c"
printf 'unsigned gh(double x){union{double d;unsigned i[2];}u;u.d=x;return u.i[1];}\n' > "$WORK/m_union.c"
printf 'struct S{double a[4];};struct S s={{0x1p-1,0x1p-2,0x1p-3,0x1p-4}};\n' > "$WORK/m_aggr.c"
for t in m_hexf m_hexd m_ld m_ldhex m_union m_aggr; do emit "DIAG-MATH $t -> $(try "$WORK/$t.c")"; done
# build-down the real pure-data file exp_data.c (crashed in v11)
"$TCC" -E $FULL src/math/exp_data.c > "$WORK/exp.i" 2>/dev/null; emit "DIAG-MATH exp_data.c -E -> $(cls $?) (lines=$(wc -l <"$WORK/exp.i" 2>/dev/null))"
emit "DIAG-MATH exp_data.c compile -> $(try src/math/exp_data.c)"
[ -s "$WORK/exp.i" ] && { cp "$WORK/exp.i" src/math/_exp_i.c; emit "DIAG-MATH exp_data.i compile -> $(try src/math/_exp_i.c)"; }
# a long double function file + a plain double trig file, to split long-double vs hex-float
emit "DIAG-MATH (real) src/math/__cosl.c -> $(try src/math/__cosl.c)   [long double]"
emit "DIAG-MATH (real) src/math/acos.c  -> $(try src/math/acos.c)    [double+hexfloat+union]"

cp "$WORK/rows.txt" "$OUTROOT/rows.txt.log" 2>/dev/null
cp "$WORK/makek.log" "$OUTROOT/makek.log" 2>/dev/null
cp "$WORK/exp.i" "$OUTROOT/exp_data.i.log" 2>/dev/null
cp "$TCC" "$OUTROOT/tcc-0.9.27" 2>/dev/null
{
  echo "============ musl-crt-diag v12 OVERNIGHT ============"
  grep -E "DIAG-PATCH|DIAG-SYSFIX|DIAG-MATH" "$WORK/rows.txt" 2>/dev/null
  echo "READ(A): DIAG-SYSFIX fails 88->~68 + linux/ empty => register-var movq fix WORKS (compile-level)."
  echo "READ(B): first DIAG-MATH CRASH pins the FP construct — m_hexf/m_hexd=hex-float lexer/fold,"
  echo "         m_ld/m_ldhex=long double x87 codegen, m_union=type-pun, m_aggr=aggregate init."
  echo "===================================================="
} | tee "$MANIFEST"
exit 0
