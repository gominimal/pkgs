#!/usr/bin/env bash
# musl-crt-diag v5 — did fix#1 (amd64-va-list.patch) work, and if not which va_list variant does
# tcc-0.9.27 accept? v4 pinned the crash to __builtin_va_list; fix#1 (typedef __va_list_struct
# __builtin_va_list[1]) applied but R4 still crashed at crt1.o (unknown: my typedef wrong, or crash
# moved past va_list). v5: (a) apply amd64-va-list.patch + `tcc -vv -c crt1.c` -> did the include
# trace get PAST va_list? (b) batch 4 self-contained va_list variants -> which compiles. set +e, exit 0.
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
emit "DIAG-INFO musl-crt-diag v5 — CC=$TCC ($("$TCC" -version 2>&1 | head -1))"

tar -xf "${SRC}.tar.gz" || { emit "FATAL untar"; cp "$WORK/rows.txt" "$MANIFEST"; exit 0; }
cd "${SRC}" || { emit "FATAL cd"; exit 0; }
# apply ALL R4 patches INCLUDING amd64-va-list (fix#1) — so crt1.c is in the FULL post-fix state
for p in makefile madvise_preserve_errno avoid_sys_clone disable_ctype_headers skip-pic-crt drop-dynamic-crt amd64-va-list; do
  patch -Np1 -i "${BUILDROOT}/${p}.patch" >/dev/null 2>&1 && emit "DIAG-INFO applied ${p}.patch" || emit "FATAL ${p}.patch DID NOT APPLY"
done
rm src/ctype/iswalpha.c src/ctype/iswalnum.c src/ctype/iswctype.c src/ctype/towctrans.c 2>/dev/null
rm include/iconv.h src/locale/iconv.c src/locale/iconv_close.c 2>/dev/null; rm -rf src/complex 2>/dev/null
CC=tcc ./configure --host=x86_64 --disable-shared --prefix=/usr --libdir=/usr/lib --includedir=/usr/include >/dev/null 2>&1
make obj/include/bits/alltypes.h obj/include/bits/syscall.h >/dev/null 2>&1
emit "DIAG-INFO setup: alltypes=$([ -f obj/include/bits/alltypes.h ] && echo OK || echo MISSING)"
INC="-D_XOPEN_SOURCE=700 -I./arch/x86_64 -I./arch/generic -Iobj/src/internal -I./src/include -I./src/internal -Iobj/include -I./include"
FULL="-std=c99 -nostdinc -ffreestanding -fexcess-precision=standard -frounding-math -Wa,--noexecstack $INC -Os -pipe -fomit-frame-pointer -fno-unwind-tables -fno-asynchronous-unwind-tables -ffunction-sections -fdata-sections -Werror=implicit-function-declaration -Werror=implicit-int -Werror=pointer-sign -Werror=pointer-arith -DSYSCALL_NO_TLS -fno-stack-protector -DCRT"

# (a) -vv crt1.c WITH fix#1 — did it compile, or crash, and did the include trace move PAST va_list?
emit "DIAG-INFO ===== (a) tcc -vv -c crt1.c WITH amd64-va-list.patch ====="
"$TCC" -vv $FULL -c -o "$WORK/crt1.o" crt/crt1.c >"$WORK/vv.out" 2>"$WORK/vv.err"
emit "DIAG-VV rc=$? ($([ -s "$WORK/crt1.o" ] && echo OBJ-OK-->FIX#1-WORKED || echo CRASH))"
emit "DIAG-VV last-includes >>> $(grep -aE '^-> | -> ' "$WORK/vv.out" 2>/dev/null | tail -8 | tr '\n' '|')"
emit "DIAG-VV stderr >>> $(tail -4 "$WORK/vv.err" 2>/dev/null | tr '\n' '|')"

# (b) batch va_list variants (self-contained) — which does tcc-0.9.27 accept?
v(){ "$TCC" -c -o "$WORK/v_$1.o" "$WORK/v_$1.c" >"$WORK/v_$1.err" 2>&1
  emit "DIAG-VAR $1 rc=$? ($([ -s "$WORK/v_$1.o" ] && echo OBJ-OK || echo CRASH)) >>> $(tail -1 "$WORK/v_$1.err" 2>/dev/null)"; }
emit "DIAG-INFO ===== (b) va_list variant bisection ====="
cat > "$WORK/v_bare.c" <<'EOF'
typedef __builtin_va_list va_list; va_list ap;
EOF
cat > "$WORK/v_mine.c" <<'EOF'
typedef struct { unsigned int gp_offset; unsigned int fp_offset; union { unsigned int overflow_offset; char *overflow_arg_area; }; char *reg_save_area; } __va_list_struct;
typedef __va_list_struct __builtin_va_list[1];
typedef __builtin_va_list va_list; va_list ap;
EOF
cat > "$WORK/v_ptr.c" <<'EOF'
typedef char *__builtin_va_list;
typedef __builtin_va_list va_list; va_list ap;
EOF
cat > "$WORK/v_direct.c" <<'EOF'
typedef struct { unsigned int gp_offset; unsigned int fp_offset; union { unsigned int overflow_offset; char *overflow_arg_area; }; char *reg_save_area; } __va_list_struct;
typedef __va_list_struct va_list[1]; va_list ap;
EOF
v bare; v mine; v ptr; v direct

cp "$TCC" "$OUTROOT/tcc-0.9.27" 2>/dev/null
cp "$WORK/rows.txt" "$OUTROOT/rows.txt.log" 2>/dev/null
for f in vv.out vv.err v_mine.err v_ptr.err v_direct.err; do [ -f "$WORK/$f" ] && cp "$WORK/$f" "$OUTROOT/$f.log"; done
{
  echo "============ musl-crt-diag v5 RESULT ============"
  grep -E "DIAG-VV|DIAG-VAR|DIAG-INFO (setup|applied amd64-va-list)" "$WORK/rows.txt" 2>/dev/null
  echo "INTERPRET: (a) OBJ-OK => fix#1 fixed crt1.c (R4 should build). (a) CRASH + last-includes PAST"
  echo "  the va_list typedef => fix#1 worked, crash MOVED to a next construct. (b) v_bare CRASH +"
  echo "  v_mine OBJ-OK => my approach is sound. If v_mine CRASH but v_ptr/v_direct OBJ-OK => use that variant."
  echo "================================================="
} | tee "$MANIFEST"
exit 0
