#!/usr/bin/env bash
# musl-crt-diag v14 — pin the math SIZE THRESHOLD. v13 ruled out the constructs: every reconstruction
# (designators, hex-float arith, long-double arrays, the faithful exp_data mini) COMPILES, and stripping
# designators AND arithmetic from the real exp_data.i BOTH still crash. The only thing separating compiling
# d_full (tab[4]) from crashing exp_data (tab[256], ~270 initializers) is SIZE. Striking clue: tcc.h
# VSTACK_SIZE=256 and exp_data.tab is EXACTLY 256 (2*(1<<7)). v14 sweeps aggregate-initializer element-count
# (dense around 256) for both double and uint64 arrays to find the exact OK->CRASH boundary:
#   threshold == 256 => tcc value-stack overflow on large flat initializers (front-end, VSTACK_SIZE).
#   threshold ~ a byte size => data-section / alloc. double-only crash => FP-constant path.
# set +e, exit 0, OutputData.
set +e
set -u
TCC=/usr/bin/tcc
VERSION="${MINIMAL_ARG_VERSION:-1.1.24}"
SRC="musl-${VERSION}"; BUILDROOT="$(pwd)"
OUTROOT=/build/output/usr/share/musl-crt-diag; WORK=/build/diag
mkdir -p "$OUTROOT" "$WORK"; MANIFEST="$OUTROOT/MANIFEST.txt"
emit(){ echo "$1"; echo "$1" >> "$WORK/rows.txt"; }
emit "DIAG-INFO musl-crt-diag v14 SIZE-THRESHOLD — $("$TCC" -version 2>&1 | head -1)"
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

# generate `const <type> a[K] = {K distinct values};` and compile it.
gen_try(){ K=$1; TYPE="$2"; SUF="$3"
  awk -v k="$K" -v t="$TYPE" -v s="$SUF" 'BEGIN{printf "const %s a[%d]={", t, k; for(i=0;i<k;i++) printf "%s%d%s",(i?",":""),i+1,s; print "};"}' > "$WORK/sz.c"
  "$TCC" $FULL -c -o "$WORK/sz.o" "$WORK/sz.c" >/dev/null 2>&1; cls $?
}

emit "DIAG-INFO ===== double[] element-count sweep (dense around 256) ====="
for K in 32 64 128 200 250 254 255 256 257 258 260 300 384 512; do
  emit "DIAG-SZ double[$K] -> $(gen_try $K double .5)"
done
emit "DIAG-INFO ===== unsigned long long[] sweep (same K) ====="
for K in 64 200 254 255 256 257 260 300 512; do
  emit "DIAG-SZ u64[$K] -> $(gen_try $K 'unsigned long long' ull)"
done
# also: NESTED like exp_data (struct{double sc; T big[K];}) — does nesting shift the threshold?
emit "DIAG-INFO ===== nested struct{double; double big[K];} sweep ====="
for K in 250 254 255 256 260; do
  awk -v k="$K" 'BEGIN{printf "struct S{double sc;double big[%d];};const struct S s={1.0,{",k; for(i=0;i<k;i++) printf "%s%d.5",(i?",":""),i+1; print "}};"}' > "$WORK/ns.c"
  "$TCC" $FULL -c -o "$WORK/ns.o" "$WORK/ns.c" >/dev/null 2>&1; emit "DIAG-SZ nested.big[$K] -> $(cls $?)"
done

cp "$WORK/rows.txt" "$OUTROOT/rows.txt.log" 2>/dev/null
cp "$TCC" "$OUTROOT/tcc-0.9.27" 2>/dev/null
{
  echo "============ musl-crt-diag v14 SIZE-THRESHOLD ============"
  grep -E "DIAG-SZ" "$WORK/rows.txt" 2>/dev/null
  echo "READ: the OK->CRASH boundary K is the threshold. ==256 => VSTACK_SIZE overflow (front-end, flat init);"
  echo "      a byte-size boundary => data-section/alloc; double-crashes-but-u64-ok => FP-constant path."
  echo "      Fix follows: tcc VSTACK_SIZE bump / init-loop fix (R3 re-seal) vs a musl table-split workaround."
  echo "========================================================="
} | tee "$MANIFEST"
exit 0
