#!/usr/bin/env bash
# musl-crt-diag v13 — pin the MATH construct. v12 showed isolated hex-float/long-double/union/POSITIONAL-
# aggregate all compile, but real math files crash — because my reconstructions missed what the real files
# actually use: exp_data.c uses C99 DESIGNATED INITIALIZERS (.invln2N = 0x1.71547652b82fep0 * N), nested
# designated arrays (.poly={...}), compile-time hex-float ARITHMETIC, and a big uint64 .tab[]. v13 tests the
# ACTUAL constructs + a true real-file reduction:
#   (A) faithful mini reproduction of exp_data + a bisection of it (drop designators / drop arith / drop tab).
#   (B) targeted isolated constructs: designated-init, hex-float*int fold, long-double const array, big u64 array.
#   (C) REAL-FILE reduction: strip designators from exp_data.i (sed) -> does it then compile? (proves designators).
# set +e, exit 0, OutputData. (amd64-syscall-arch.patch now in the set — keeps the linux/ cluster clear.)
set +e
set -u
TCC=/usr/bin/tcc
VERSION="${MINIMAL_ARG_VERSION:-1.1.24}"
SRC="musl-${VERSION}"; BUILDROOT="$(pwd)"
OUTROOT=/build/output/usr/share/musl-crt-diag; WORK=/build/diag
mkdir -p "$OUTROOT" "$WORK"; MANIFEST="$OUTROOT/MANIFEST.txt"
emit(){ echo "$1"; echo "$1" >> "$WORK/rows.txt"; }
emit "DIAG-INFO musl-crt-diag v13 MATH-PIN — $("$TCC" -version 2>&1 | head -1)"
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

# (A) faithful mini of exp_data + bisection
emit "DIAG-INFO ===== (A) faithful exp_data mini + bisection ====="
TAB='0x0ull,0x3ff0000000000000ull,0x3fe0000000000000ull,0x4008000000000000ull'
cat > "$WORK/d_full.c" <<EOF
#define N 128
struct ed { double invln2N; double shift; double poly[4]; unsigned long long tab[4]; };
const struct ed __d = {
  .invln2N = 0x1.71547652b82fep0 * N,
  .shift = 0x1.8p52,
  .poly = { 0x1.ffffffffffdbdp-2, 0x1.555555555543cp-3, 0x1.55555cf172b91p-5, 0x1.1111167a4d017p-7 },
  .tab = { $TAB },
};
EOF
# variants: drop designators (positional) / drop the *N arithmetic / drop the tab array
cat > "$WORK/d_nodesig.c" <<EOF
#define N 128
struct ed { double invln2N; double shift; double poly[4]; unsigned long long tab[4]; };
const struct ed __d = { 0x1.71547652b82fep0 * N, 0x1.8p52, { 0x1.ffffffffffdbdp-2, 0x1.555555555543cp-3, 0x1.55555cf172b91p-5, 0x1.1111167a4d017p-7 }, { $TAB } };
EOF
cat > "$WORK/d_noarith.c" <<EOF
struct ed { double invln2N; double poly[4]; };
const struct ed __d = { .invln2N = 0x1.71547652b82fep0, .poly = { 0x1.ffffffffffdbdp-2, 0x1.555555555543cp-3, 0x1.55555cf172b91p-5, 0x1.1111167a4d017p-7 } };
EOF
cat > "$WORK/d_notab.c" <<EOF
#define N 128
struct ed { double invln2N; double shift; double poly[4]; };
const struct ed __d = { .invln2N = 0x1.71547652b82fep0 * N, .shift = 0x1.8p52, .poly = { 0x1.ffffffffffdbdp-2, 0x1.555555555543cp-3 } };
EOF
for t in d_full d_nodesig d_noarith d_notab; do emit "DIAG-MINI $t -> $(try "$WORK/$t.c")"; done

# (B) targeted isolated constructs
emit "DIAG-INFO ===== (B) isolated constructs ====="
printf '#define N 128\ndouble x(void){return 0x1.71547652b82fep0 * N;}\n' > "$WORK/b_arith.c"
printf 'struct S{double a;double b[2];};const struct S s={.a=0x1p-1,.b={0x1p-2,0x1p-3}};\n' > "$WORK/b_desig.c"
printf 'const struct S{double a;double b[2];}s={.a=1.0,.b={2.0,3.0}};\n' > "$WORK/b_desig_dec.c"
printf 'static const long double t[3]={0x1.fp-3L,0x1.1p-2L,0x1.2p-1L};long double f(int i){return t[i];}\n' > "$WORK/b_ldarr.c"
printf 'static const unsigned long long tab[256]={1,2,3};unsigned long long g(int i){return tab[i];}\n' > "$WORK/b_u64.c"
for t in b_arith b_desig b_desig_dec b_ldarr b_u64; do emit "DIAG-CONS $t -> $(try "$WORK/$t.c")"; done

# (C) REAL-FILE reduction: strip designators from exp_data.i, does it then compile?
emit "DIAG-INFO ===== (C) real exp_data.i designator-strip reduction ====="
"$TCC" -E $FULL src/math/exp_data.c > "$WORK/exp.i" 2>/dev/null
emit "DIAG-REAL exp_data.c (control) -> $(try src/math/exp_data.c)"
sed -E 's/\.[A-Za-z_][A-Za-z0-9_]*[[:space:]]*=[[:space:]]*//g' "$WORK/exp.i" > src/math/_exp_nodesig.c
emit "DIAG-REAL exp_data.i designators-STRIPPED -> $(try src/math/_exp_nodesig.c)   [OK here => designators are the crash]"
# also: strip just the arithmetic (* N) but keep designators
sed -E 's/\* N//g; s/\* \(1[^)]*\)//g' "$WORK/exp.i" > src/math/_exp_noarith.c
emit "DIAG-REAL exp_data.i arithmetic-STRIPPED -> $(try src/math/_exp_noarith.c)"

cp "$WORK/rows.txt" "$OUTROOT/rows.txt.log" 2>/dev/null
cp "$WORK/exp.i" "$OUTROOT/exp_data.i.log" 2>/dev/null
cp "$TCC" "$OUTROOT/tcc-0.9.27" 2>/dev/null
{
  echo "============ musl-crt-diag v13 MATH-PIN ============"
  grep -E "DIAG-MINI|DIAG-CONS|DIAG-REAL" "$WORK/rows.txt" 2>/dev/null
  echo "READ: d_full CRASH + the variant that flips to OK pins it (nodesig=designators, noarith=hexfloat-fold,"
  echo "      notab=the big array). DIAG-REAL strip-confirms on the REAL file. b_* isolate each construct."
  echo "==================================================="
} | tee "$MANIFEST"
exit 0
