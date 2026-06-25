#!/usr/bin/env bash
# musl-crt-diag v7 — PIN + FIX the syscall_arch.h construct. v6 found the breadth split: 11/24 crash,
# and EVERY crasher includes arch/x86_64/syscall_arch.h (the -vv aio trace dies right after it); every
# passer is pure computation. Hypothesis: x86_64 __syscall4/5/6 use GNU local register variables
# (`register long r10 __asm__("r10") = a4;`) which tcc-0.9.27 mishandles; tcc codegens every static
# inline (no DCE) so any file including the header drags in __syscall6 -> crash. i386 (live-bootstrap's
# arch) has no r8-r15, so this is amd64-net-new. This probe, in ONE cycle:
#   (a) BISECT — compile standalone TUs with __syscall0/3/4/6 in isolation; pins the crashing arity.
#   (b) FIX MATRIX — compile fix candidates that drop the register-vars for an in-asm `movq %N,%%r10`
#       (F1="r"(a4) input, F2="g"(a4) input), report which COMPILE.
#   (c) END-TO-END — overwrite arch/x86_64/syscall_arch.h with the winning variant and recompile the
#       11 real v6 crashers; count OK now. If all 11 flip OK => the fix is the R4 syscall-arch patch.
# Probe: bash, set +e, never aborts, exits 0 with greppable DIAG- rows + OutputData.
set +e
set -u
TCC=/usr/bin/tcc
VERSION="${MINIMAL_ARG_VERSION:-1.1.24}"
SRC="musl-${VERSION}"; BUILDROOT="$(pwd)"
OUTROOT=/build/output/usr/share/musl-crt-diag; WORK=/build/diag
mkdir -p "$OUTROOT" "$WORK"; MANIFEST="$OUTROOT/MANIFEST.txt"
emit(){ echo "$1"; echo "$1" >> "$WORK/rows.txt"; }
emit "DIAG-INFO musl-crt-diag v7 SYSCALL-FIX — $("$TCC" -version 2>&1 | head -1)"
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

# Preserve the pristine header for the end-to-end re-test.
cp arch/x86_64/syscall_arch.h "$WORK/syscall_arch.pristine.h"

# ── (a) BISECTION — each __syscallN in isolation, forced live by a `use` referent ──
emit "DIAG-INFO ===== (a) bisect __syscallN arities ====="
cat > "$WORK/c0.c" <<'EOF'
static long s0(long n){unsigned long r;__asm__ __volatile__("syscall":"=a"(r):"a"(n):"rcx","r11","memory");return r;}
long use0(long n){return s0(n);}
EOF
cat > "$WORK/c3.c" <<'EOF'
static long s3(long n,long a,long b,long c){unsigned long r;__asm__ __volatile__("syscall":"=a"(r):"a"(n),"D"(a),"S"(b),"d"(c):"rcx","r11","memory");return r;}
long use3(long n,long a,long b,long c){return s3(n,a,b,c);}
EOF
cat > "$WORK/c4.c" <<'EOF'
static long s4(long n,long a,long b,long c,long d){unsigned long r;register long r10 __asm__("r10")=d;__asm__ __volatile__("syscall":"=a"(r):"a"(n),"D"(a),"S"(b),"d"(c),"r"(r10):"rcx","r11","memory");return r;}
long use4(long n,long a,long b,long c,long d){return s4(n,a,b,c,d);}
EOF
cat > "$WORK/c6.c" <<'EOF'
static long s6(long n,long a,long b,long c,long d,long e,long f){unsigned long r;register long r10 __asm__("r10")=d;register long r8 __asm__("r8")=e;register long r9 __asm__("r9")=f;__asm__ __volatile__("syscall":"=a"(r):"a"(n),"D"(a),"S"(b),"d"(c),"r"(r10),"r"(r8),"r"(r9):"rcx","r11","memory");return r;}
long use6(long n,long a,long b,long c,long d,long e,long f){return s6(n,a,b,c,d,e,f);}
EOF
for t in c0 c3 c4 c6; do emit "DIAG-BISECT $t -> $(try "$WORK/$t.c")"; done

# ── (b) FIX MATRIX — drop register-vars; mov the high args into r10/r8/r9 inside the asm ──
emit "DIAG-INFO ===== (b) fix candidates for __syscall4/5/6 ====="
# F1: high args as "r" inputs, explicit movq into r10/r8/r9, those regs clobbered.
cat > "$WORK/f1.c" <<'EOF'
static long s4(long n,long a,long b,long c,long d){unsigned long r;__asm__ __volatile__("movq %5,%%r10 ; syscall":"=a"(r):"a"(n),"D"(a),"S"(b),"d"(c),"r"(d):"rcx","r11","r10","memory");return r;}
static long s6(long n,long a,long b,long c,long d,long e,long f){unsigned long r;__asm__ __volatile__("movq %5,%%r10 ; movq %6,%%r8 ; movq %7,%%r9 ; syscall":"=a"(r):"a"(n),"D"(a),"S"(b),"d"(c),"r"(d),"r"(e),"r"(f):"rcx","r11","r8","r9","r10","memory");return r;}
long u4(long n,long a,long b,long c,long d){return s4(n,a,b,c,d);}
long u6(long n,long a,long b,long c,long d,long e,long f){return s6(n,a,b,c,d,e,f);}
EOF
# F2: same but "g" (general: reg/mem/imm) inputs — fallback if "r" can't reach a free reg.
cat > "$WORK/f2.c" <<'EOF'
static long s4(long n,long a,long b,long c,long d){unsigned long r;__asm__ __volatile__("movq %5,%%r10 ; syscall":"=a"(r):"a"(n),"D"(a),"S"(b),"d"(c),"g"(d):"rcx","r11","r10","memory");return r;}
static long s6(long n,long a,long b,long c,long d,long e,long f){unsigned long r;__asm__ __volatile__("movq %5,%%r10 ; movq %6,%%r8 ; movq %7,%%r9 ; syscall":"=a"(r):"a"(n),"D"(a),"S"(b),"d"(c),"g"(d),"g"(e),"g"(f):"rcx","r11","r8","r9","r10","memory");return r;}
long u4(long n,long a,long b,long c,long d){return s4(n,a,b,c,d);}
long u6(long n,long a,long b,long c,long d,long e,long f){return s6(n,a,b,c,d,e,f);}
EOF
F1=$(try "$WORK/f1.c"); F2=$(try "$WORK/f2.c")
emit "DIAG-FIX F1(r-input,movq) -> $F1"
emit "DIAG-FIX F2(g-input,movq) -> $F2"

# ── (c) END-TO-END — patch the REAL header with the winning variant, recompile the 11 v6 crashers ──
WIN=""; [ "$F1" = OK ] && WIN=F1; [ -z "$WIN" ] && [ "$F2" = OK ] && WIN=F2
emit "DIAG-INFO ===== (c) end-to-end re-test of v6 crashers (winner=${WIN:-NONE}) ====="
if [ -n "$WIN" ]; then
  # Surgically swap s4/s5/s6 in-place with awk (gawk-bootstrap dep — NO python in builder userland),
  # preserving the pristine preamble/tail exactly. INP = the input constraint of the winner.
  if [ "$WIN" = F1 ]; then INP='"r"'; else INP='"g"'; fi
  cat > "$WORK/swap.awk" <<'AWKEOF'
/^static __inline long __syscall4\(/ { skip=4; next }
/^static __inline long __syscall5\(/ { skip=5; next }
/^static __inline long __syscall6\(/ { skip=6; next }
skip>0 {
  if ($0 ~ /^\}/) {
    if (skip==4) {
      print "static __inline long __syscall4(long n, long a1, long a2, long a3, long a4)"
      print "{"; print "\tunsigned long ret;"
      print "\t__asm__ __volatile__ (\"movq %5,%%r10 ; syscall\" : \"=a\"(ret) : \"a\"(n), \"D\"(a1), \"S\"(a2), \"d\"(a3), " INP "(a4) : \"rcx\", \"r11\", \"r10\", \"memory\");"
      print "\treturn ret;"; print "}"
    } else if (skip==5) {
      print "static __inline long __syscall5(long n, long a1, long a2, long a3, long a4, long a5)"
      print "{"; print "\tunsigned long ret;"
      print "\t__asm__ __volatile__ (\"movq %5,%%r10 ; movq %6,%%r8 ; syscall\" : \"=a\"(ret) : \"a\"(n), \"D\"(a1), \"S\"(a2), \"d\"(a3), " INP "(a4), " INP "(a5) : \"rcx\", \"r11\", \"r8\", \"r10\", \"memory\");"
      print "\treturn ret;"; print "}"
    } else {
      print "static __inline long __syscall6(long n, long a1, long a2, long a3, long a4, long a5, long a6)"
      print "{"; print "\tunsigned long ret;"
      print "\t__asm__ __volatile__ (\"movq %5,%%r10 ; movq %6,%%r8 ; movq %7,%%r9 ; syscall\" : \"=a\"(ret) : \"a\"(n), \"D\"(a1), \"S\"(a2), \"d\"(a3), " INP "(a4), " INP "(a5), " INP "(a6) : \"rcx\", \"r11\", \"r8\", \"r9\", \"r10\", \"memory\");"
      print "\treturn ret;"; print "}"
    }
    skip=0
  }
  next
}
{ print }
AWKEOF
  awk -v INP="$INP" -f "$WORK/swap.awk" "$WORK/syscall_arch.pristine.h" > arch/x86_64/syscall_arch.h
  emit "DIAG-INFO patched header s4/s5/s6 -> movq form; verify it still has 7 __syscallN:"
  emit "DIAG-INFO   __syscallN count = $(grep -c '__inline long __syscall' arch/x86_64/syscall_arch.h)"
  CR="src/aio/aio.c src/stdio/fputs.c src/stdio/vfprintf.c src/malloc/malloc.c src/thread/pthread_mutex_lock.c src/errno/strerror.c src/unistd/read.c src/signal/raise.c src/locale/setlocale.c src/regex/regcomp.c src/dirent/opendir.c"
  ok=0; bad=0; still=""
  for f in $CR; do
    [ -f "$f" ] || continue
    "$TCC" $FULL -c -o "$WORK/e.o" "$f" >"$WORK/e.err" 2>&1; rc=$?
    if [ "$rc" = 0 ]; then ok=$((ok+1)); else bad=$((bad+1)); still="$still $(basename $f)($rc)"; fi
  done
  emit "DIAG-E2E winner=$WIN  flipped-OK=$ok / 11   still-failing:$still"
  cp arch/x86_64/syscall_arch.h "$OUTROOT/syscall_arch.fixed.h" 2>/dev/null
else
  emit "DIAG-E2E NO fix candidate compiled — both F1 & F2 failed; need a different rewrite."
fi

cp "$WORK/rows.txt" "$OUTROOT/rows.txt.log" 2>/dev/null
cp "$WORK/syscall_arch.pristine.h" "$OUTROOT/syscall_arch.pristine.h" 2>/dev/null
cp "$TCC" "$OUTROOT/tcc-0.9.27" 2>/dev/null
{
  echo "============ musl-crt-diag v7 SYSCALL-FIX ============"
  grep -E "DIAG-BISECT|DIAG-FIX|DIAG-E2E" "$WORK/rows.txt" 2>/dev/null
  echo "READ: bisect pins the crashing arity (expect c0/c3 OK, c4/c6 CRASH => register-vars)."
  echo "      E2E flipped-OK=11/11 => syscall-arch-tcc.patch is the R4 fix (movq form, Tier-3)."
  echo "====================================================="
} | tee "$MANIFEST"
exit 0
