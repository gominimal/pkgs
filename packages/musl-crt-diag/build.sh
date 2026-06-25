#!/usr/bin/env bash
# musl-crt-diag v8 — the crash is NOT syscall_arch.h. v7 proved: c4 OK / c6 CRASH (tcc chokes on r8/r9
# register-vars, NOT r10), F2(movq+"g") compiles, BUT swapping s4/s5/s6 flipped 0/11 of the real
# crashers. read.c references NO inline syscall (it calls the extern __syscall_cp) and 7-arg calls
# compile fine (f2.c). The ONLY thing every crasher includes that no passer does is src/internal/syscall.h,
# whose unique construct is:   hidden long __syscall_ret(unsigned long), __syscall_cp(syscall_arg_t,x7);
# i.e. __attribute__((visibility("hidden"))) on a 2-declarator decl w/ a 7-param prototype. getenv (passer)
# calls hidden externs too but they're declared WITHOUT the attribute -> not fatal. So suspect = the
# visibility attribute and/or the attributed multi-declarator. v8, one cycle:
#   (a) BISECT — visibility-on-single-proto / multi-declarator-no-attr / the EXACT construct / read-faithful.
#   (b) FIX — FX1 (empty `hidden`) vs FX2 (split the declarator). Which COMPILES.
#   (c) END-TO-END — apply the winner to the REAL header (features.h empty-hidden, or syscall.h split),
#       recompile all 11 v6 crashers; flipped-OK=11 => that's the R4 patch.
set +e
set -u
TCC=/usr/bin/tcc
VERSION="${MINIMAL_ARG_VERSION:-1.1.24}"
SRC="musl-${VERSION}"; BUILDROOT="$(pwd)"
OUTROOT=/build/output/usr/share/musl-crt-diag; WORK=/build/diag
mkdir -p "$OUTROOT" "$WORK"; MANIFEST="$OUTROOT/MANIFEST.txt"
emit(){ echo "$1"; echo "$1" >> "$WORK/rows.txt"; }
emit "DIAG-INFO musl-crt-diag v8 HIDDEN-DECL — $("$TCC" -version 2>&1 | head -1)"
tar -xf "${SRC}.tar.gz" 2>/dev/null; cd "${SRC}" || { emit FATAL; exit 0; }
for p in makefile madvise_preserve_errno avoid_sys_clone disable_ctype_headers skip-pic-crt drop-dynamic-crt amd64-va-list; do
  patch -Np1 -i "${BUILDROOT}/${p}.patch" >/dev/null 2>&1
done
rm src/ctype/iswalpha.c src/ctype/iswalnum.c src/ctype/iswctype.c src/ctype/towctrans.c 2>/dev/null
rm include/iconv.h src/locale/iconv.c src/locale/iconv_close.c 2>/dev/null; rm -rf src/complex 2>/dev/null
CC=tcc ./configure --host=x86_64 --disable-shared --prefix=/usr --libdir=/usr/lib --includedir=/usr/include >/dev/null 2>&1
make obj/include/bits/alltypes.h obj/include/bits/syscall.h >/dev/null 2>&1
FULL="-std=c99 -nostdinc -ffreestanding -fexcess-precision=standard -frounding-math -Wa,--noexecstack -D_XOPEN_SOURCE=700 -I./arch/x86_64 -I./arch/generic -Iobj/src/internal -I./src/include -I./src/internal -Iobj/include -I./include -Os -pipe -fomit-frame-pointer -fno-unwind-tables -fno-asynchronous-unwind-tables -ffunction-sections -fdata-sections -DSYSCALL_NO_TLS -fno-stack-protector"
cls(){ rc=$1; if [ "$rc" = 0 ]; then echo OK; elif [ "$rc" -gt 128 ] 2>/dev/null; then echo "CRASH(rc=$rc)"; else echo "err(rc=$rc)"; fi; }
try(){ "$TCC" $FULL -c -o "$WORK/t.o" "$1" >"$WORK/t.err" 2>&1; cls $?; }
cp src/include/features.h "$WORK/features.pristine.h"
cp src/internal/syscall.h "$WORK/syscall.pristine.h"

# ── (a) BISECTION of the hidden multi-declarator construct ──
emit "DIAG-INFO ===== (a) bisect the hidden/multi-declarator construct ====="
cat > "$WORK/bvis.c" <<'EOF'
__attribute__((__visibility__("hidden"))) long f(unsigned long);
long u(unsigned long x){return f(x);}
EOF
cat > "$WORK/bmul.c" <<'EOF'
long f(unsigned long), g(long,long,long,long,long,long,long);
long u(unsigned long x){return f(x)+g((long)x,0,0,0,0,0,0);}
EOF
cat > "$WORK/bfull.c" <<'EOF'
typedef long syscall_arg_t;
__attribute__((__visibility__("hidden"))) long f(unsigned long),
  g(syscall_arg_t,syscall_arg_t,syscall_arg_t,syscall_arg_t,syscall_arg_t,syscall_arg_t,syscall_arg_t);
long u(unsigned long x){return f(x)+g((long)x,0,0,0,0,0,0);}
EOF
cat > "$WORK/bread.c" <<'EOF'
#define hidden __attribute__((__visibility__("hidden")))
#define __scc(X) ((long)(X))
typedef long syscall_arg_t;
hidden long __syscall_ret(unsigned long),
  __syscall_cp(syscall_arg_t,syscall_arg_t,syscall_arg_t,syscall_arg_t,syscall_arg_t,syscall_arg_t,syscall_arg_t);
long read_(int fd,void*buf,unsigned long count){
  return __syscall_ret((__syscall_cp)(0,__scc(fd),__scc(buf),__scc(count),0,0,0));
}
EOF
for t in bvis bmul bfull bread; do emit "DIAG-BISECT $t -> $(try "$WORK/$t.c")"; done

# ── (b) FIX CANDIDATES ──
emit "DIAG-INFO ===== (b) fix candidates ====="
cat > "$WORK/fx1.c" <<'EOF'
#define hidden
#define __scc(X) ((long)(X))
typedef long syscall_arg_t;
hidden long __syscall_ret(unsigned long),
  __syscall_cp(syscall_arg_t,syscall_arg_t,syscall_arg_t,syscall_arg_t,syscall_arg_t,syscall_arg_t,syscall_arg_t);
long read_(int fd,void*buf,unsigned long count){return __syscall_ret((__syscall_cp)(0,__scc(fd),__scc(buf),__scc(count),0,0,0));}
EOF
cat > "$WORK/fx2.c" <<'EOF'
#define hidden __attribute__((__visibility__("hidden")))
#define __scc(X) ((long)(X))
typedef long syscall_arg_t;
hidden long __syscall_ret(unsigned long);
hidden long __syscall_cp(syscall_arg_t,syscall_arg_t,syscall_arg_t,syscall_arg_t,syscall_arg_t,syscall_arg_t,syscall_arg_t);
long read_(int fd,void*buf,unsigned long count){return __syscall_ret((__syscall_cp)(0,__scc(fd),__scc(buf),__scc(count),0,0,0));}
EOF
FX1=$(try "$WORK/fx1.c"); FX2=$(try "$WORK/fx2.c")
emit "DIAG-FIX FX1(empty-hidden)     -> $FX1"
emit "DIAG-FIX FX2(split-declarator) -> $FX2"

# ── (c) END-TO-END on the 11 real crashers with the winning fix ──
CR="src/aio/aio.c src/stdio/fputs.c src/stdio/vfprintf.c src/malloc/malloc.c src/thread/pthread_mutex_lock.c src/errno/strerror.c src/unistd/read.c src/signal/raise.c src/locale/setlocale.c src/regex/regcomp.c src/dirent/opendir.c"
e2e(){ ok=0; still=""; for f in $CR; do [ -f "$f" ] || continue; "$TCC" $FULL -c -o "$WORK/e.o" "$f" >/dev/null 2>&1 && ok=$((ok+1)) || still="$still $(basename $f)"; done; echo "$ok|$still"; }
WIN=NONE
if [ "$FX1" = OK ]; then
  WIN=FX1; emit "DIAG-INFO ===== (c) e2e via empty-hidden in features.h ====="
  sed -i 's@^#define hidden __attribute__.*@#define hidden@' src/include/features.h
  R=$(e2e); emit "DIAG-E2E winner=FX1(empty-hidden)  flipped-OK=${R%%|*} / 11   still:${R#*|}"
elif [ "$FX2" = OK ]; then
  WIN=FX2; emit "DIAG-INFO ===== (c) e2e via split-declarator in syscall.h ====="
  # split the `hidden long __syscall_ret(...),\n ...__syscall_cp(...);` into two `hidden long` stmts
  awk 'BEGIN{d=0}
    /^hidden long __syscall_ret\(unsigned long\),/{print "hidden long __syscall_ret(unsigned long);";print "hidden long __syscall_cp(syscall_arg_t, syscall_arg_t, syscall_arg_t, syscall_arg_t, syscall_arg_t, syscall_arg_t, syscall_arg_t);";d=1;next}
    d==1{ if($0 ~ /;[ \t]*$/) d=0; next }
    {print}' "$WORK/syscall.pristine.h" > src/internal/syscall.h
  R=$(e2e); emit "DIAG-E2E winner=FX2(split)  flipped-OK=${R%%|*} / 11   still:${R#*|}"
else
  emit "DIAG-E2E neither FX1 nor FX2 compiled — construct is elsewhere; need tracer on read.c."
fi

cp "$WORK/rows.txt" "$OUTROOT/rows.txt.log" 2>/dev/null
cp "$TCC" "$OUTROOT/tcc-0.9.27" 2>/dev/null
{
  echo "============ musl-crt-diag v8 HIDDEN-DECL ============"
  grep -E "DIAG-BISECT|DIAG-FIX|DIAG-E2E" "$WORK/rows.txt" 2>/dev/null
  echo "READ: which bisect TU crashes pins it (bvis=visibility attr, bmul=multi-declarator, bfull=both)."
  echo "      E2E flipped 11/11 => winner is the R4 patch (FX1=features.h empty-hidden / FX2=syscall.h split)."
  echo "====================================================="
} | tee "$MANIFEST"
exit 0
