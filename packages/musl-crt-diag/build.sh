#!/usr/bin/env bash
# musl-crt-diag v2 — pin the EXACT crt1.c C construct that segfaults tcc-0.9.27, with STANDALONE
# snippets (no musl includes -> no alltypes.h fidelity gap, no tracer needed: tcc-0.9.27 miscompiles
# the tracer). v1 localized it to crt1.c's C (not asm, not flags); v2 isolates WHICH construct +
# tests fix candidates (named params / typedef). set +e, never abort, exit 0 with greppable rows.
set +e
set -u
TCC=/usr/bin/tcc
OUTROOT=/build/output/usr/share/musl-crt-diag
WORK=/build/diag
mkdir -p "$OUTROOT" "$WORK"
MANIFEST="$OUTROOT/MANIFEST.txt"
emit(){ echo "$1"; echo "$1" >> "$WORK/rows.txt"; }
emit "DIAG-INFO musl-crt-diag v2 — CC=$TCC ($("$TCC" -version 2>&1 | head -1))"

# compile a snippet with tcc-0.9.27; report rc + OBJ + stderr-tail. The crt1.c flags include the C99
# freestanding set, but v1 b3 proved flags are fine on trivial C, so use minimal -c here.
t(){ local lab="$1" src="$2"
  printf '%s\n' "$src" > "$WORK/$lab.c"
  "$TCC" -c -o "$WORK/$lab.o" "$WORK/$lab.c" >"$WORK/$lab.err" 2>&1
  local rc=$?
  emit "DIAG-CONSTRUCT $lab rc=$rc ($([ -s "$WORK/$lab.o" ] && echo OBJ-OK || echo NO-OBJ/CRASH)) >>> $(tail -1 "$WORK/$lab.err" 2>/dev/null | tr '\n' '|')"
}

emit "DIAG-INFO ===== standalone construct bisection (crt1.c's C, no includes) ====="
# the actual crt1.c constructs (musl-1.1.24 crt/crt1.c):
t s0_trivial      'int x; void f(long*p){(void)p;}'
t s1_unnamed_fp   'int __libc_start_main(int (*)(), int, char **, void (*)(), void(*)(), void(*)());'
t s2_weak         '__attribute__((__weak__)) void _init(void); __attribute__((__weak__)) void _fini(void);'
t s3_call_fp      'int __libc_start_main(int(*)(),int,char**,void(*)(),void(*)(),void(*)()); int main(); __attribute__((__weak__)) void _init(void); __attribute__((__weak__)) void _fini(void); void _start_c(long*p){int argc=p[0];char**argv=(void*)(p+1);__libc_start_main(main,argc,argv,_init,_fini,0);}'
# === FIX CANDIDATES (if s1/s3 crash) ===
t f1_named_fp     'int __libc_start_main(int (*main_fn)(), int argc, char **argv, void (*init)(), void(*fini)(), void(*rtld)());'
t f2_typedef_fp   'typedef int (*main_t)(); typedef void (*vfn_t)(); int __libc_start_main(main_t, int, char **, vfn_t, vfn_t, vfn_t);'
t f3_typedef_call 'typedef int (*main_t)(); typedef void (*vfn_t)(); int __libc_start_main(main_t,int,char**,vfn_t,vfn_t,vfn_t); int main(); __attribute__((__weak__)) void _init(void); __attribute__((__weak__)) void _fini(void); void _start_c(long*p){int argc=p[0];char**argv=(void*)(p+1);__libc_start_main((main_t)main,argc,argv,(vfn_t)_init,(vfn_t)_fini,0);}'

emit "DIAG-INFO ===== INTERPRET ====="
emit "DIAG-INFO s0 OBJ-OK (sanity). If s1/s3 CRASH but f2/f3 (typedef) OBJ-OK => tcc-0.9.27 chokes on"
emit "DIAG-INFO   the UNNAMED inline func-ptr param/arg; fix = typedef the func-ptr types in crt1.c."
emit "DIAG-INFO   If f1 (named) OBJ-OK => naming the params suffices. If s2 CRASH => the weak attr."

# save tcc-0.9.27 (unstripped) + logs
cp "$TCC" "$OUTROOT/tcc-0.9.27" 2>/dev/null && emit "DIAG-INFO saved tcc-0.9.27 ($(wc -c < "$OUTROOT/tcc-0.9.27") bytes)"
cp "$WORK/rows.txt" "$OUTROOT/rows.txt.log" 2>/dev/null
for s in s1_unnamed_fp s3_call_fp f2_typedef_fp; do [ -f "$WORK/$s.err" ] && cp "$WORK/$s.err" "$OUTROOT/$s.err.log"; done

{
  echo "============ musl-crt-diag v2 RESULT ============"
  echo "CC: $("$TCC" -version 2>&1 | head -1)"
  grep -E "DIAG-CONSTRUCT|INTERPRET" "$WORK/rows.txt" 2>/dev/null
  echo "================================================="
} | tee "$MANIFEST"
exit 0
