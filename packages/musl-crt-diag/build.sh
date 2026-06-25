#!/usr/bin/env bash
# musl-crt-diag — PIN why tcc-0.9.27 SIGSEGVs compiling musl crt/crt1.c (the R4 wall). Replays R4's
# extract/patch/configure, then diagnoses `tcc -c crt1.c` instead of `make`: (a) ptrace tracer →
# backtrace, (b) asm-vs-C bisection. set +e, never abort, ALWAYS exit 0 with greppable rows + outputs.
set +e
set -u

TCC=/usr/bin/tcc                 # R3's tcc-0.9.27 (CC=tcc in R4) — the compiler under test
VERSION="${MINIMAL_ARG_VERSION:-1.1.24}"
SRC="musl-${VERSION}"
BUILDROOT="$(pwd)"
OUTROOT=/build/output/usr/share/musl-crt-diag
WORK=/build/diag
mkdir -p "$OUTROOT" "$WORK"
MANIFEST="$OUTROOT/MANIFEST.txt"
emit(){ echo "$1"; echo "$1" >> "$WORK/rows.txt"; }

emit "DIAG-INFO musl-crt-diag — CC=$TCC ($("$TCC" -version 2>&1 | head -1))"

# ── replay R4: unpack + patch + the rm's + configure (identical to stage0-musl-1.1.24/build.sh) ──
tar -xf "${SRC}.tar.gz" || { emit "FATAL untar"; cp "$WORK/rows.txt" "$MANIFEST"; exit 0; }
cd "${SRC}" || { emit "FATAL cd"; exit 0; }
for p in makefile madvise_preserve_errno avoid_sys_clone disable_ctype_headers skip-pic-crt drop-dynamic-crt; do
  patch -Np1 -i "${BUILDROOT}/${p}.patch" >/dev/null 2>&1 && emit "DIAG-INFO applied ${p}.patch" || emit "FATAL ${p}.patch failed"
done
rm src/ctype/iswalpha.c src/ctype/iswalnum.c src/ctype/iswctype.c src/ctype/towctrans.c 2>/dev/null
rm include/iconv.h src/locale/iconv.c src/locale/iconv_close.c 2>/dev/null
rm -rf src/complex 2>/dev/null
CC=tcc ./configure --host=x86_64 --disable-shared --prefix=/usr --libdir=/usr/lib --includedir=/usr/include \
  >"$WORK/configure.out" 2>&1
emit "DIAG-INFO configure rc=$? ($([ -f config.mak ] && echo config.mak-OK || echo NO-config.mak); $([ -f obj/include/bits/alltypes.h ] && echo alltypes-OK || echo NO-alltypes))"

# the EXACT crt1.o compile flags (from the failed R4 build log / config.mak):
C99="-std=c99 -nostdinc -ffreestanding -fexcess-precision=standard -frounding-math -Wa,--noexecstack"
INC="-D_XOPEN_SOURCE=700 -I./arch/x86_64 -I./arch/generic -Iobj/src/internal -I./src/include -I./src/internal -Iobj/include -I./include"
OPT="-Os -pipe -fomit-frame-pointer -fno-unwind-tables -fno-asynchronous-unwind-tables -ffunction-sections -fdata-sections"
WERR="-Werror=implicit-function-declaration -Werror=implicit-int -Werror=pointer-sign -Werror=pointer-arith"
FULL="$C99 $INC $OPT $WERR -DSYSCALL_NO_TLS -fno-stack-protector -DCRT"

# ── build the ptrace tracer (compiled by tcc-0.9.27 itself) ──
cat > "$WORK/trace.c" <<'TRACE_EOF'
typedef long L;
static L sc(L n,L a,L b,L c,L d){ L r;
  __asm__ volatile("movq %1,%%rax\n\t movq %2,%%rdi\n\t movq %3,%%rsi\n\t movq %4,%%rdx\n\t movq %5,%%r10\n\t syscall\n\t movq %%rax,%0\n\t"
    : "=m"(r) : "m"(n),"m"(a),"m"(b),"m"(c),"m"(d) : "rax","rdi","rsi","rdx","r10","rcx","r11","memory"); return r; }
static void ws(const char*s){ int n=0; while(s[n])n++; sc(1,2,(L)s,n,0); }
static void wn(L v){ char b[19]; b[0]='0'; b[1]='x'; int i; for(i=0;i<16;i++){int d=(v>>((15-i)*4))&0xf; b[2+i]=d<10?('0'+d):('a'+d-10);} b[18]='\n'; sc(1,2,(L)b,19,0); }
int main(int ac,char**av,char**ev){
  L pid=sc(57,0,0,0,0);                                  /* fork */
  if(pid==0){ sc(101,0,0,0,0); sc(59,(L)av[1],(L)&av[1],(L)ev,0); ws("EXECVE-FAILED\n"); sc(60,127,0,0,0); }
  int st; L regs[40]; int k;
  sc(61,pid,(L)&st,0,0);                                 /* exec-stop */
  sc(101,7,pid,0,0);                                     /* CONT */
  for(;;){ L w=sc(61,pid,(L)&st,0,0);
    if(w<0){ ws("WAIT<0\n"); return 0; }
    if((st&0x7f)==0){ ws("EXITED code="); wn((st>>8)&0xff); return 0; }
    if((st&0x7f)!=0x7f){ ws("KILLED-sig="); wn(st&0x7f); return 0; }
    int sig=(st>>8)&0xff;
    if(sig==11||sig==4||sig==6||sig==8){
      sc(101,12,pid,0,(L)regs);
      ws("CRASH sig="); wn(sig); ws("rip="); wn(regs[16]); ws("rbp="); wn(regs[4]); ws("rsp="); wn(regs[19]);
      ws("rdi="); wn(regs[14]); ws("rsi="); wn(regs[13]); ws("rax="); wn(regs[10]);
      ws("BACKTRACE:\n"); wn(regs[16]); L rbp=regs[4];
      for(k=0;k<40 && rbp>0x1000;k++){ L ret=0,nxt=0; if(sc(101,2,pid,rbp+8,(L)&ret)!=0)break; if(sc(101,2,pid,rbp,(L)&nxt)!=0)break; wn(ret); rbp=nxt; }
      sc(101,8,pid,0,0); return 0; }
    sc(101,7,pid,sig,0); }
}
TRACE_EOF
if "$TCC" -static -o "$WORK/trace" "$WORK/trace.c" >"$WORK/trace-build.err" 2>&1 && [ -s "$WORK/trace" ]; then
  chmod 755 "$WORK/trace"; emit "DIAG-INFO tracer built OK"
else
  emit "FATAL tracer build failed >>> $(tail -3 "$WORK/trace-build.err" 2>/dev/null | tr '\n' '|')"
fi

# ── (a) reproduce + BACKTRACE: tcc -c crt1.c under the tracer ──
emit "DIAG-INFO ===== (a) trace: tcc -c crt1.c (FULL flags) ====="
( "$WORK/trace" "$TCC" $FULL -c -o "$WORK/crt1.o" crt/crt1.c ) >"$WORK/tr-crt1.out" 2>&1
while IFS= read -r ln; do emit "DIAG-TRACE $ln"; done < "$WORK/tr-crt1.out"

# ── (b) BISECT: asm-only vs C-only vs minimal — isolate the crashing construct ──
emit "DIAG-INFO ===== (b) bisection ====="
# b1: the C BODY only — crt_arch.h asm replaced by a trivial _start (does the C crash tcc?)
sed 's@#include "crt_arch.h"@__asm__(".text\\n.global _start\\n_start:\\n\\tcall _start_c\\n");@' crt/crt1.c > "$WORK/crt1_noasm.c"
"$TCC" $FULL -c -o "$WORK/b1.o" "$WORK/crt1_noasm.c" >"$WORK/b1.err" 2>&1
emit "DIAG-BISECT b1 C-only(asm-stubbed) rc=$? ($([ -s "$WORK/b1.o" ] && echo OBJ-OK || echo NO-OBJ)) >>> $(tail -2 "$WORK/b1.err" 2>/dev/null | tr '\n' '|')"
# b2: the crt_arch.h ASM only (+ a dummy _start_c) — does the asm alone crash tcc?
{ cat arch/x86_64/crt_arch.h; echo 'void _start_c(long*p){(void)p;}'; } | sed 's/START/"_start"/g' > "$WORK/asmonly.c" 2>/dev/null
# crt_arch.h uses START macro; define it instead:
{ echo '#define START "_start"'; cat arch/x86_64/crt_arch.h; echo 'void _start_c(long*p){(void)p;}'; } > "$WORK/asmonly.c"
"$TCC" $C99 -c -o "$WORK/b2.o" "$WORK/asmonly.c" >"$WORK/b2.err" 2>&1
emit "DIAG-BISECT b2 asm-only rc=$? ($([ -s "$WORK/b2.o" ] && echo OBJ-OK || echo NO-OBJ)) >>> $(tail -2 "$WORK/b2.err" 2>/dev/null | tr '\n' '|')"
# b3: trivial C with the FULL flags (sanity — flags on minimal C; probes said yes)
echo 'int x; void f(long*p){(void)p;}' > "$WORK/triv.c"
"$TCC" $FULL -c -o "$WORK/b3.o" "$WORK/triv.c" >"$WORK/b3.err" 2>&1
emit "DIAG-BISECT b3 trivial-C+FULLflags rc=$? ($([ -s "$WORK/b3.o" ] && echo OBJ-OK || echo NO-OBJ)) >>> $(tail -2 "$WORK/b3.err" 2>/dev/null | tr '\n' '|')"
# b4: crt1.c with SIMPLE flags (like R3's unified-libc.c that worked) — is it the flags or the content?
"$TCC" -c $INC -o "$WORK/b4.o" crt/crt1.c >"$WORK/b4.err" 2>&1
emit "DIAG-BISECT b4 crt1.c+SIMPLEflags rc=$? ($([ -s "$WORK/b4.o" ] && echo OBJ-OK || echo NO-OBJ)) >>> $(tail -2 "$WORK/b4.err" 2>/dev/null | tr '\n' '|')"
# b5: run b1 (C-only) under the tracer too if it crashed — backtrace of the C path
if [ ! -s "$WORK/b1.o" ]; then
  ( "$WORK/trace" "$TCC" $FULL -c -o "$WORK/b1t.o" "$WORK/crt1_noasm.c" ) >"$WORK/tr-b1.out" 2>&1
  while IFS= read -r ln; do emit "DIAG-TRACE-b1 $ln"; done < "$WORK/tr-b1.out"
fi

# ── save tcc-0.9.27 (unstripped) + logs for objdump ──
cp "$TCC" "$OUTROOT/tcc-0.9.27" 2>/dev/null && emit "DIAG-INFO saved tcc-0.9.27 ($(wc -c < "$OUTROOT/tcc-0.9.27") bytes)"
for f in "$WORK"/tr-crt1.out "$WORK"/b1.err "$WORK"/b2.err "$WORK"/b4.err "$WORK"/configure.out "$WORK"/rows.txt; do
  [ -f "$f" ] && cp "$f" "$OUTROOT/$(basename "$f").log"
done

{
  echo "============ musl-crt-diag RESULT ============"
  echo "CC: $TCC ($("$TCC" -version 2>&1 | head -1))"
  cat "$WORK/rows.txt" 2>/dev/null | grep -E "DIAG-TRACE|DIAG-BISECT|CRASH|EXITED|rip="
  echo "INTERPRET: b1 OBJ-OK + b2 crash => the crt_arch.h ASM is the culprit (bisect the instrs).";
  echo "           b1 crash + b2 OBJ-OK => the C (decls/_start_c) is it. b3 OBJ-OK confirms flags are fine.";
  echo "           map the BACKTRACE rip addrs via: objdump -d tcc-0.9.27 (saved).";
  echo "=============================================="
} | tee "$MANIFEST"
exit 0
