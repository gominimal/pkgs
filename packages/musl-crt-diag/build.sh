#!/usr/bin/env bash
# musl-crt-diag v3 — FAITHFUL reproduction of R4's crt1.c crash + -vv include trace (the R3-diag win).
# v2 proved the crt1.c C *constructs* compile fine standalone → the crash needs the musl INCLUDES.
# v1/v2 had a fidelity gap (no `make` → no generated alltypes.h). v3: configure THEN generate the
# headers `make` would (alltypes.h/syscall.h), so crt1.c's includes resolve exactly like R4 — then
# `tcc -vv -c crt1.c` shows the include chain + WHERE it dies (R3-style), plus a -w test (warning vs
# error) and an include bisection. set +e, never abort, exit 0.
set +e
set -u
TCC=/usr/bin/tcc
VERSION="${MINIMAL_ARG_VERSION:-1.1.24}"
SRC="musl-${VERSION}"
BUILDROOT="$(pwd)"
OUTROOT=/build/output/usr/share/musl-crt-diag
WORK=/build/diag
mkdir -p "$OUTROOT" "$WORK"
MANIFEST="$OUTROOT/MANIFEST.txt"
emit(){ echo "$1"; echo "$1" >> "$WORK/rows.txt"; }
emit "DIAG-INFO musl-crt-diag v3 — CC=$TCC ($("$TCC" -version 2>&1 | head -1))"

# ── replay R4: unpack + patch + rm's + configure ──
tar -xf "${SRC}.tar.gz" || { emit "FATAL untar"; cp "$WORK/rows.txt" "$MANIFEST"; exit 0; }
cd "${SRC}" || { emit "FATAL cd"; exit 0; }
for p in makefile madvise_preserve_errno avoid_sys_clone disable_ctype_headers skip-pic-crt drop-dynamic-crt; do
  patch -Np1 -i "${BUILDROOT}/${p}.patch" >/dev/null 2>&1 && emit "DIAG-INFO applied ${p}.patch" || emit "FATAL ${p}.patch"
done
rm src/ctype/iswalpha.c src/ctype/iswalnum.c src/ctype/iswctype.c src/ctype/towctrans.c 2>/dev/null
rm include/iconv.h src/locale/iconv.c src/locale/iconv_close.c 2>/dev/null
rm -rf src/complex 2>/dev/null
CC=tcc ./configure --host=x86_64 --disable-shared --prefix=/usr --libdir=/usr/lib --includedir=/usr/include >"$WORK/configure.out" 2>&1
emit "DIAG-INFO configure rc=$?"

# ── FIDELITY FIX: generate the headers `make` makes (alltypes.h + syscall.h) — so crt1.c resolves like R4 ──
make obj/include/bits/alltypes.h obj/include/bits/syscall.h >"$WORK/genh.out" 2>&1
emit "DIAG-INFO genh rc=$? alltypes=$([ -f obj/include/bits/alltypes.h ] && echo OK || echo MISSING) syscall=$([ -f obj/include/bits/syscall.h ] && echo OK || echo MISSING)"

FULL="-std=c99 -nostdinc -ffreestanding -fexcess-precision=standard -frounding-math -Wa,--noexecstack -D_XOPEN_SOURCE=700 -I./arch/x86_64 -I./arch/generic -Iobj/src/internal -I./src/include -I./src/internal -Iobj/include -I./include -Os -pipe -fomit-frame-pointer -fno-unwind-tables -fno-asynchronous-unwind-tables -ffunction-sections -fdata-sections -Werror=implicit-function-declaration -Werror=implicit-int -Werror=pointer-sign -Werror=pointer-arith -DSYSCALL_NO_TLS -fno-stack-protector -DCRT"

# ── (a) FAITHFUL reproduce + -vv include trace (R3-style: the last header before the crash) ──
emit "DIAG-INFO ===== (a) tcc -vv -c crt1.c (FAITHFUL: alltypes.h present) ====="
"$TCC" -vv $FULL -c -o "$WORK/crt1.o" crt/crt1.c >"$WORK/vv.out" 2>"$WORK/vv.err"
emit "DIAG-VV rc=$? ($([ -s "$WORK/crt1.o" ] && echo OBJ-OK || echo NO-OBJ/CRASH))"
emit "DIAG-VV last-includes >>> $(grep -aE '^-> | -> ' "$WORK/vv.out" 2>/dev/null | tail -6 | tr '\n' '|')"
emit "DIAG-VV stdout-tail >>> $(tail -3 "$WORK/vv.out" 2>/dev/null | tr '\n' '|')"
emit "DIAG-VV stderr-tail >>> $(tail -4 "$WORK/vv.err" 2>/dev/null | tr '\n' '|')"

# ── (b) -w test: is it a WARNING-triggered error-varargs crash (R3-class), or a real ERROR? ──
"$TCC" -w $FULL -c -o "$WORK/crt1w.o" crt/crt1.c >"$WORK/w.err" 2>&1
emit "DIAG-W crt1.c -w rc=$? ($([ -s "$WORK/crt1w.o" ] && echo OBJ-OK-->was-a-WARNING || echo still-CRASH-->real-ERROR))"

# ── (c) include bisection: which include pulls the crash? ──
printf '#include <features.h>\n' > "$WORK/i_feat.c"
"$TCC" $FULL -c -o "$WORK/i_feat.o" "$WORK/i_feat.c" >"$WORK/i_feat.err" 2>&1
emit "DIAG-INC features.h-only rc=$? ($([ -s "$WORK/i_feat.o" ] && echo OBJ-OK || echo CRASH)) >>> $(tail -1 "$WORK/i_feat.err" 2>/dev/null)"
printf '#include <features.h>\n#include "libc.h"\n' > "$WORK/i_libc.c"
"$TCC" $FULL -c -o "$WORK/i_libc.o" "$WORK/i_libc.c" >"$WORK/i_libc.err" 2>&1
emit "DIAG-INC features.h+libc.h rc=$? ($([ -s "$WORK/i_libc.o" ] && echo OBJ-OK || echo CRASH)) >>> $(tail -1 "$WORK/i_libc.err" 2>/dev/null)"

cp "$TCC" "$OUTROOT/tcc-0.9.27" 2>/dev/null
cp "$WORK/rows.txt" "$OUTROOT/rows.txt.log" 2>/dev/null
for f in vv.out vv.err w.err i_feat.err i_libc.err genh.out; do [ -f "$WORK/$f" ] && cp "$WORK/$f" "$OUTROOT/$f.log"; done
{
  echo "============ musl-crt-diag v3 RESULT ============"
  grep -E "DIAG-VV|DIAG-W|DIAG-INC|DIAG-INFO (genh|configure)" "$WORK/rows.txt" 2>/dev/null
  echo "INTERPRET: DIAG-VV last-includes = the header tcc was in at the crash (R3-style). -w OBJ-OK =>"
  echo "  warning-triggered error-varargs (suppress/fix the formatter). features.h/libc.h CRASH => bisect that header."
  echo "================================================="
} | tee "$MANIFEST"
exit 0
