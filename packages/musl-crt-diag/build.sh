#!/usr/bin/env bash
# musl-crt-diag v4 — pin the EXACT musl-header construct that crashes tcc-0.9.27's amd64 codegen.
# v3 (faithful, alltypes.h present) localized R4's crash to libc.h's includes (features.h OK;
# features.h+libc.h CRASH; -w doesn't help -> real codegen crash, dies after stdio.h's alltypes.h).
# v4 batches ALL suspects in ONE cycle (burn-rate lesson): the two headers standalone + self-contained
# construct snippets (long double / _Noreturn / anon-union / __builtin_va_list typedef). set +e, exit 0.
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
emit "DIAG-INFO musl-crt-diag v4 — CC=$TCC ($("$TCC" -version 2>&1 | head -1))"

tar -xf "${SRC}.tar.gz" || { emit "FATAL untar"; cp "$WORK/rows.txt" "$MANIFEST"; exit 0; }
cd "${SRC}" || { emit "FATAL cd"; exit 0; }
for p in makefile madvise_preserve_errno avoid_sys_clone disable_ctype_headers skip-pic-crt drop-dynamic-crt; do
  patch -Np1 -i "${BUILDROOT}/${p}.patch" >/dev/null 2>&1 || emit "FATAL ${p}.patch"
done
rm src/ctype/iswalpha.c src/ctype/iswalnum.c src/ctype/iswctype.c src/ctype/towctrans.c 2>/dev/null
rm include/iconv.h src/locale/iconv.c src/locale/iconv_close.c 2>/dev/null; rm -rf src/complex 2>/dev/null
CC=tcc ./configure --host=x86_64 --disable-shared --prefix=/usr --libdir=/usr/lib --includedir=/usr/include >/dev/null 2>&1
make obj/include/bits/alltypes.h obj/include/bits/syscall.h >/dev/null 2>&1
emit "DIAG-INFO faithful setup: alltypes=$([ -f obj/include/bits/alltypes.h ] && echo OK || echo MISSING)"

INC="-D_XOPEN_SOURCE=700 -I./arch/x86_64 -I./arch/generic -Iobj/src/internal -I./src/include -I./src/internal -Iobj/include -I./include"

# (A) WHICH header? compile each musl header standalone in the configured tree
hdr(){ printf '#include <%s>\nint _x;\n' "$1" > "$WORK/h_$2.c"
  "$TCC" $INC -c -o "$WORK/h_$2.o" "$WORK/h_$2.c" >"$WORK/h_$2.err" 2>&1
  emit "DIAG-HDR $1 rc=$? ($([ -s "$WORK/h_$2.o" ] && echo OBJ-OK || echo CRASH)) >>> $(tail -1 "$WORK/h_$2.err" 2>/dev/null)"
}
emit "DIAG-INFO ===== (A) which musl header crashes? ====="
hdr stdlib.h stdlib
hdr stdio.h stdio

# (B) WHICH construct? self-contained snippets (no musl includes), minimal -c
k(){ printf '%s\n' "$2" > "$WORK/k_$1.c"
  "$TCC" -c -o "$WORK/k_$1.o" "$WORK/k_$1.c" >"$WORK/k_$1.err" 2>&1
  emit "DIAG-K $1 rc=$? ($([ -s "$WORK/k_$1.o" ] && echo OBJ-OK || echo CRASH)) >>> $(tail -1 "$WORK/k_$1.err" 2>/dev/null)"
}
emit "DIAG-INFO ===== (B) which construct crashes tcc-0.9.27? ====="
k ldstruct  'struct S { long long __ll; long double __ld; }; struct S maxalign;'   # max_align_t
k ldfn      'long double strtold(const char*, char**); long double f(long double x){ return x; }'  # long double codegen
k noreturn  '__attribute__((__noreturn__)) void abort(void); void h(void){ abort(); }'  # _Noreturn
k anonunion 'struct S { union { int __i[14]; volatile int __vi[14]; unsigned long __s[7]; } __u; }; struct S t;'  # pthread_attr_t
k valist_td '__builtin_va_list va_list_check; typedef __builtin_va_list valt;'        # alltypes va_list TYPEDEF
k restrict_ 'int fgetpos(void *__restrict, void *__restrict);'                        # __restrict (->restrict)

# the culprit construct: re-run under -vv won't help (no tracer here); save tcc + logs for objdump
cp "$TCC" "$OUTROOT/tcc-0.9.27" 2>/dev/null
cp "$WORK/rows.txt" "$OUTROOT/rows.txt.log" 2>/dev/null
for f in h_stdlib h_stdio k_ldstruct k_ldfn k_noreturn k_anonunion; do [ -f "$WORK/$f.err" ] && cp "$WORK/$f.err" "$OUTROOT/$f.err.log"; done
{
  echo "============ musl-crt-diag v4 RESULT ============"
  grep -E "DIAG-HDR|DIAG-K|DIAG-INFO faithful" "$WORK/rows.txt" 2>/dev/null
  echo "INTERPRET: the CRASH rows pin it. A construct k_* that CRASHES standalone = the tcc-0.9.27 bug;"
  echo "  fix = patch musl's header to avoid it (Tier-3) OR fix tcc-0.9.27 codegen (re-seal R3 if systemic)."
  echo "================================================="
} | tee "$MANIFEST"
exit 0
