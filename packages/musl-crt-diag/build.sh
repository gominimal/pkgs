#!/usr/bin/env bash
# musl-crt-diag v15 — the FINALLY-identified untested construct. v13 ruled out constructs, v14 ruled out
# size. The real exp_data.tab is full of LARGE UNSUFFIXED hex integers with bit 63 set (0xbc7160139cd8dc5d,
# 0x3ff0000000000000) — and EVERY one of my prior reconstructions used small / ull-suffixed / decimal
# values, NEVER a large unsuffixed hex. On amd64 (LONG_SIZE=8) such a constant lexes to TOK_CLONG/CULONG
# (the `long` type, t = VT_LLONG|VT_LONG[|VT_UNSIGNED]); on i386 (LONG_SIZE=4) the SAME literal lexes to
# CLLONG/CULLONG — so the `long`-constant path is amd64-ONLY, never exercised by live-bootstrap (i386). v15:
#   (A) isolated: one/array of large UNSUFFIXED bit-63 hex vs the SAME with `ull` suffix; + bit-63-CLEAR
#       (signed-fitting -> CLONG) to split signed-long vs unsigned-long.
#   (B) REAL reduction: suffix every 16-hex-digit tab value in exp_data.i with `ull` (regex matches the
#       uint64 tab entries, NOT the 0x1.xp hex floats) -> does it then COMPILE? (proves unsuffixed-hex).
set +e
set -u
TCC=/usr/bin/tcc
VERSION="${MINIMAL_ARG_VERSION:-1.1.24}"
SRC="musl-${VERSION}"; BUILDROOT="$(pwd)"
OUTROOT=/build/output/usr/share/musl-crt-diag; WORK=/build/diag
mkdir -p "$OUTROOT" "$WORK"; MANIFEST="$OUTROOT/MANIFEST.txt"
emit(){ echo "$1"; echo "$1" >> "$WORK/rows.txt"; }
emit "DIAG-INFO musl-crt-diag v15 CLONG-HEX — $("$TCC" -version 2>&1 | head -1)"
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

# (A) isolated tests of the UNSUFFIXED large-hex (CLONG/CULONG) construct
emit "DIAG-INFO ===== (A) unsuffixed large-hex (CLONG/CULONG) ====="
printf 'unsigned long long x(void){return 0xbc7160139cd8dc5d;}\n' > "$WORK/a_one_ns.c"          # bit63 set, unsuffixed -> CULONG
printf 'unsigned long long x(void){return 0xbc7160139cd8dc5dull;}\n' > "$WORK/a_one_su.c"        # same, suffixed -> CULLONG
printf 'unsigned long long x(void){return 0x3c9b3b4f1a88bf6e;}\n' > "$WORK/a_one_clong.c"        # bit63 CLEAR, fits signed long -> CLONG
printf 'static const unsigned long long t[8]={0x0,0x3ff0000000000000,0x3c9b3b4f1a88bf6e,0x3feff63da9fb3335,0xbc7160139cd8dc5d,0x3fefec9a3e778061,0xbc905e7a108766d1,0x3fefe315e86e7f85};unsigned long long g(int i){return t[i];}\n' > "$WORK/a_arr_ns.c"
printf 'static const unsigned long long t[8]={0x0ull,0x3ff0000000000000ull,0x3c9b3b4f1a88bf6eull,0x3feff63da9fb3335ull,0xbc7160139cd8dc5dull,0x3fefec9a3e778061ull,0xbc905e7a108766d1ull,0x3fefe315e86e7f85ull};unsigned long long g(int i){return t[i];}\n' > "$WORK/a_arr_su.c"
for t in a_one_ns a_one_su a_one_clong a_arr_ns a_arr_su; do emit "DIAG-HEX $t -> $(try "$WORK/$t.c")"; done

# (B) REAL-FILE reduction: suffix every 16-hex-digit value in exp_data.i with `ull`, recompile
emit "DIAG-INFO ===== (B) real exp_data.i: suffix 16-digit hex with ull ====="
"$TCC" -E $FULL src/math/exp_data.c > "$WORK/exp.i" 2>/dev/null
emit "DIAG-REAL exp_data.c (control) -> $(try src/math/exp_data.c)"
sed -E 's/(0x[0-9a-fA-F]{16})/\1ull/g' "$WORK/exp.i" > src/math/_exp_ull.c
emit "DIAG-REAL exp_data.i 16-hex-suffixed-ull -> $(try src/math/_exp_ull.c)   [OK => unsuffixed large hex IS the crash]"
emit "DIAG-INFO (suffix count applied: $(grep -aoE '0x[0-9a-fA-F]{16}ull' src/math/_exp_ull.c | wc -l))"

cp "$WORK/rows.txt" "$OUTROOT/rows.txt.log" 2>/dev/null
cp "$TCC" "$OUTROOT/tcc-0.9.27" 2>/dev/null
{
  echo "============ musl-crt-diag v15 CLONG-HEX ============"
  grep -E "DIAG-HEX|DIAG-REAL" "$WORK/rows.txt" 2>/dev/null
  echo "READ: a_arr_ns CRASH + a_arr_su OK + DIAG-REAL ull-suffixed OK => tcc amd64 miscompiles UNSUFFIXED"
  echo "      large hex (CLONG/CULONG). a_one_* says single-vs-array. Fix: tcc parse/CLONG path (R3 re-seal)."
  echo "===================================================="
} | tee "$MANIFEST"
exit 0
