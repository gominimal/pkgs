#!/usr/bin/env bash
# musl-crt-diag v16 — STOP testing constructs; LOCALIZE. v13(constructs) v14(size) v15(hex-typing) all
# wrong: nothing stripped from real exp_data.i compiles, no synthetic reproduces. Decisive cuts:
#   (1) noinit   — remove the = {..} initializer from exp_data.i -> compiles? (crash in DECL/headers vs INIT)
#   (2) faithful — self-contained clone: inline struct + the REAL init from exp_data.c, typedef uint64_t as
#       `unsigned long` (musl's ACTUAL amd64 type — every prior u64 test used `unsigned long long`!). NO musl
#       headers. crash here => reproducible+bisectable & it's the struct/init; OK => needs the musl header chain.
#   (3) faithful_ull — same but uint64_t = `unsigned long long` -> does the typedef BASE TYPE (long vs longlong) matter?
# Pins header-vs-init, struct-context, and unsigned-long-vs-longlong in one cycle.
set +e
set -u
TCC=/usr/bin/tcc
VERSION="${MINIMAL_ARG_VERSION:-1.1.24}"
SRC="musl-${VERSION}"; BUILDROOT="$(pwd)"
OUTROOT=/build/output/usr/share/musl-crt-diag; WORK=/build/diag
mkdir -p "$OUTROOT" "$WORK"; MANIFEST="$OUTROOT/MANIFEST.txt"
emit(){ echo "$1"; echo "$1" >> "$WORK/rows.txt"; }
emit "DIAG-INFO musl-crt-diag v16 LOCALIZE — $("$TCC" -version 2>&1 | head -1)"
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

emit "DIAG-LOC control exp_data.c -> $(try src/math/exp_data.c)"

# (1) noinit: strip the initializer from the real preprocessed file
"$TCC" -E $FULL src/math/exp_data.c > "$WORK/exp.i" 2>/dev/null
awk '/const struct exp_data __exp_data = \{/{print "const struct exp_data __exp_data;"; skip=1; next} skip&&/^\};/{skip=0; next} skip{next} {print}' "$WORK/exp.i" > src/math/_noinit.c
emit "DIAG-LOC noinit (init removed) -> $(try src/math/_noinit.c)   [OK => crash is the INIT; CRASH => crash is DECL/headers]"

# (2)(3) faithful self-contained clone (NO musl headers), with the REAL init body from exp_data.c
PRE='#define EXP_TABLE_BITS 7
#define EXP_POLY_ORDER 5
#define EXP_USE_TOINT_NARROW 0
#define EXP2_POLY_ORDER 5
#define N (1 << EXP_TABLE_BITS)
struct exp_data { double invln2N; double shift; double negln2hiN; double negln2loN; double poly[4]; double exp2_shift; double exp2_poly[EXP2_POLY_ORDER]; uint64_t tab[2*(1 << EXP_TABLE_BITS)]; };'
{ echo 'typedef unsigned long uint64_t;'; echo "$PRE"; sed -n '/const struct exp_data __exp_data/,$p' src/math/exp_data.c; } > "$WORK/faithful.c"
{ echo 'typedef unsigned long long uint64_t;'; echo "$PRE"; sed -n '/const struct exp_data __exp_data/,$p' src/math/exp_data.c; } > "$WORK/faithful_ull.c"
emit "DIAG-LOC faithful (uint64_t=unsigned long,   NO musl hdrs) -> $(try "$WORK/faithful.c")"
emit "DIAG-LOC faithful (uint64_t=unsigned long long, NO musl hdrs) -> $(try "$WORK/faithful_ull.c")"

# bonus: if faithful crashes, try it with tab truncated to 8 (does shrinking the real tab help in-context?)
if [ "$(try "$WORK/faithful.c")" != OK ]; then
  awk 'BEGIN{n=0} /\.tab = \{/{print; intab=1; next} intab{ if($0 ~ /^\}/){intab=0;print "};";next} if(n<4){print; n++} ; next} {print}' "$WORK/faithful.c" | sed '$ s/$/\n/' > "$WORK/faithful_smalltab.c"
  emit "DIAG-LOC faithful tab-truncated-to-~8 -> $(try "$WORK/faithful_smalltab.c")"
fi

cp "$WORK/rows.txt" "$OUTROOT/rows.txt.log" 2>/dev/null
cp "$WORK/faithful.c" "$OUTROOT/faithful.c.log" 2>/dev/null
cp "$TCC" "$OUTROOT/tcc-0.9.27" 2>/dev/null
{
  echo "============ musl-crt-diag v16 LOCALIZE ============"
  grep -E "DIAG-LOC" "$WORK/rows.txt" 2>/dev/null
  echo "READ: noinit OK => it's the INITIALIZER. faithful CRASH => reproducible self-contained (bisect it);"
  echo "      faithful OK => needs musl header chain. faithful vs faithful_ull => unsigned long vs long long."
  echo "==================================================="
} | tee "$MANIFEST"
exit 0
