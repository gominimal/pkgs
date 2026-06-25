#!/usr/bin/env bash
# tcc-0.9.27-diag — UNMASK the R3 crash: tcc-0.9.26 (sealed R2 deliverable) SIGSEGVs compiling
# tcc-0.9.27's tcc.c (GP-fault ≈ strlen/error-formatting, masked). Probe, not a trust rung: set +e,
# never abort, ALWAYS exit 0 with greppable rows + the backtrace + the saved binary for objdump.
set +e
set -u

PREFIX=/usr
TCC_PKG=tcc-0.9.27
TCC=/usr/bin/tcc-0.9.26            # the SEALED R2 deliverable — the compiler UNDER TEST
OUTROOT=/build/output/usr/share/tcc-0.9.27-diag
WORK=/build/diag
mkdir -p "$OUTROOT" "$WORK"
MANIFEST="$OUTROOT/MANIFEST.txt"
emit(){ echo "$1"; echo "$1" >> "$WORK/rows.txt"; }

emit "DIAG-INFO begin tcc-0.9.27-diag — compiler under test: $TCC"
emit "DIAG-INFO $("$TCC" -version 2>&1 | head -1)"
[ -d "/build/$TCC_PKG" ] || { echo "FATAL: /build/$TCC_PKG missing" | tee "$MANIFEST"; exit 0; }
command -v simple-patch >/dev/null 2>&1 || { echo "FATAL simple-patch missing" | tee "$MANIFEST"; exit 0; }

# ── PHASE 1: apply R3's EXACT tcc-0.9.27 source patches (so the crash reproduces faithfully) ──
cd "/build/$TCC_PKG" || { echo "FATAL cd"; exit 0; }
simple-patch tcctools.c /build/remove-fileopen.before /build/remove-fileopen.after \
  && simple-patch tcctools.c /build/addback-fileopen.before /build/addback-fileopen.after \
  && emit "DIAG-INFO tcctools.c fopen patches applied" || emit "FATAL tcctools.c patch failed"
simple-patch tccelf.c /build/fiwix-paddr.before /build/fiwix-paddr.after \
  && emit "DIAG-INFO fiwix-paddr applied" || emit "FATAL fiwix-paddr patch failed"
simple-patch tccelf.c /build/check-reloc-null.before /build/check-reloc-null.after \
  && emit "DIAG-INFO check-reloc-null applied" || emit "FATAL check-reloc-null patch failed"
: > config.h

# the EXACT R3 tcc.c-compile flags (stage0-tcc-0.9.27/tcc.kaem), but -c (compile-only: the crash is
# during compile, before the link, so -c reproduces it and isolates the compile phase).
ARGS=(
  -c -o "$WORK/tcc.o"
  -D TCC_TARGET_X86_64=1
  -D "CONFIG_TCCDIR=\"/usr/lib/mes/tcc\"" -D "CONFIG_TCC_CRTPREFIX=\"/usr/lib/mes\""
  -D "CONFIG_TCC_ELFINTERP=\"/mes/loader\"" -D "CONFIG_TCC_LIBPATHS=\"/usr/lib/mes:/usr/lib/mes/tcc\""
  -D "CONFIG_TCC_SYSINCLUDEPATHS=\"/usr/include/mes\"" -D "TCC_LIBGCC=\"/usr/lib/mes/libc.a\""
  -D CONFIG_TCC_STATIC=1 -D CONFIG_USE_LIBGCC=1 -D "TCC_VERSION=\"0.9.27\"" -D ONE_SOURCE=1
  -I . -I "$PREFIX/include" -I "$PREFIX/include/mes" tcc.c
)

# ── PHASE 2: confirm the crash + capture the LAST verbose action before it (which file/phase) ──
emit "DIAG-INFO ===== (a) -vv verbose compile (last action before crash) ====="
timeout 120 "$TCC" -vv "${ARGS[@]}" >"$WORK/vv.out" 2>"$WORK/vv.err"; vrc=$?
emit "DIAG-VV rc=$vrc ($([ -s "$WORK/tcc.o" ] && echo OBJ-OK || echo NO-OBJ))"
emit "DIAG-VV stdout-tail >>> $(tail -4 "$WORK/vv.out" 2>/dev/null | tr '\n' '|')"
emit "DIAG-VV stderr-tail >>> $(tail -6 "$WORK/vv.err" 2>/dev/null | tr '\n' '|')"
rm -f "$WORK/tcc.o"

# ── PHASE 3: build the ptrace TRACER (compiled by tcc-0.9.26, the correct compiler) ──
# Adapted from tcc-boot0-diag: CONT then waitpid-LOOP catches the SIGSEGV EXACTLY (R3 crashes, it does
# not hang, so no sleep/SIGSTOP). Prints rip + the rbp-chain return addresses; map via local objdump.
cat > "$WORK/trace.c" <<'TRACE_EOF'
typedef long L;
static L sc(L n,L a,L b,L c,L d){
  L r;
  __asm__ volatile(
    "movq %1,%%rax\n\t movq %2,%%rdi\n\t movq %3,%%rsi\n\t movq %4,%%rdx\n\t movq %5,%%r10\n\t syscall\n\t movq %%rax,%0\n\t"
    : "=m"(r) : "m"(n),"m"(a),"m"(b),"m"(c),"m"(d)
    : "rax","rdi","rsi","rdx","r10","rcx","r11","memory");
  return r;
}
static void ws(const char*s){ int n=0; while(s[n])n++; sc(1,2,(L)s,n,0); }
static void wn(L v){ char b[19]; b[0]='0'; b[1]='x'; int i; for(i=0;i<16;i++){int d=(v>>((15-i)*4))&0xf; b[2+i]=d<10?('0'+d):('a'+d-10);} b[18]='\n'; sc(1,2,(L)b,19,0); }
int main(int ac,char**av,char**ev){
  L pid=sc(57,0,0,0,0);                                  /* fork */
  if(pid==0){ sc(101,0,0,0,0);                           /* PTRACE_TRACEME */
    sc(59,(L)av[1],(L)&av[1],(L)ev,0);                   /* execve(av[1], &av[1], envp) */
    ws("EXECVE-FAILED\n"); sc(60,127,0,0,0); }
  ws("pid="); wn(pid);
  int st; L regs[40]; int k;
  sc(61,pid,(L)&st,0,0);                                 /* waitpid: exec-stop (SIGTRAP) */
  sc(101,7,pid,0,0);                                     /* PTRACE_CONT (no re-inject) */
  for(;;){
    L w=sc(61,pid,(L)&st,0,0);                           /* waitpid: next stop/exit */
    if(w<0){ ws("WAIT<0\n"); return 0; }
    if((st&0x7f)==0){ ws("EXITED code="); wn((st>>8)&0xff); return 0; }
    if((st&0x7f)!=0x7f){ ws("KILLED-sig="); wn(st&0x7f); return 0; }
    int sig=(st>>8)&0xff;
    if(sig==11||sig==4||sig==6||sig==8){                 /* SEGV/ILL/ABRT/FPE = the crash */
      sc(101,12,pid,0,(L)regs);                          /* PTRACE_GETREGS */
      ws("CRASH sig="); wn(sig);
      ws("rip="); wn(regs[16]); ws("rbp="); wn(regs[4]); ws("rsp="); wn(regs[19]);
      ws("rdi="); wn(regs[14]); ws("rsi="); wn(regs[13]); ws("rax="); wn(regs[10]);
      ws("BACKTRACE (rip, then rbp-chain return addrs):\n"); wn(regs[16]);
      L rbp=regs[4];
      for(k=0;k<40 && rbp>0x1000;k++){ L ret=0,nxt=0;
        if(sc(101,2,pid,rbp+8,(L)&ret)!=0)break;
        if(sc(101,2,pid,rbp,(L)&nxt)!=0)break;
        wn(ret); rbp=nxt; }
      sc(101,8,pid,0,0);                                 /* PTRACE_KILL */
      return 0;
    }
    sc(101,7,pid,sig,0);                                 /* deliver other signal + continue */
  }
}
TRACE_EOF
if timeout 120 "$TCC" -static -o "$WORK/trace" "$WORK/trace.c" >"$WORK/trace-build.err" 2>&1 && [ -s "$WORK/trace" ]; then
  /usr/bin/chmod 755 "$WORK/trace"
  emit "DIAG-INFO tracer built OK"
  emit "DIAG-INFO ===== (b) ptrace tcc-0.9.26 -c tcc.c — backtrace at the SIGSEGV ====="
  ( cd "/build/$TCC_PKG" && timeout 120 "$WORK/trace" "$TCC" "${ARGS[@]}" ) >"$WORK/trace.out" 2>&1
  while IFS= read -r ln; do emit "DIAG-TRACE $ln"; done < "$WORK/trace.out"
else
  emit "FATAL tracer build FAILED >>> $(tail -4 "$WORK/trace-build.err" 2>/dev/null | tr '\n' '|')"
fi

# ── PHASE 4: save tcc-0.9.26 (UNSTRIPPED, built with -g) for LOCAL objdump of the backtrace addrs ──
/usr/bin/cp "$TCC" "$OUTROOT/tcc-0.9.26" 2>/dev/null \
  && emit "DIAG-INFO saved tcc-0.9.26 ($(/usr/bin/wc -c < "$OUTROOT/tcc-0.9.26") bytes) for objdump" \
  || emit "DIAG-INFO could not save tcc-0.9.26"
for f in "$WORK"/vv.err "$WORK"/vv.out "$WORK"/trace.out "$WORK"/rows.txt "$WORK"/trace-build.err; do
  [ -f "$f" ] && /usr/bin/cp "$f" "$OUTROOT/$(/usr/bin/basename "$f").log"
done

# ── MANIFEST ──
{
  echo "================ tcc-0.9.27-diag RESULT ================"
  echo "host: $(/usr/bin/uname -a 2>/dev/null)"
  echo "compiler under test: $TCC  ($("$TCC" -version 2>&1 | head -1))"
  echo "----- rows (greppable on stdout too) -----"
  /usr/bin/cat "$WORK/rows.txt" 2>/dev/null
  echo "-------------------------------------------------------"
  echo "NEXT: objdump -d --start-address=<rip> tcc-0.9.26 | head  (map rip + each BACKTRACE addr to a fn);"
  echo "  the fn that hands strlen/the formatter a non-canonical ptr is the miscompiled one -> patch tcc.c"
  echo "  (like fix-shift/fix-plt). The -vv stderr-tail names the last file/phase before the crash."
  echo "ARTIFACTS (gs://minimalmertic-sign-staging/tcc-0.9.27-diag-1.0-a/usr/share/tcc-0.9.27-diag/):"
  for f in "$OUTROOT"/*; do [ "$f" = "$MANIFEST" ] && continue; printf '  %-26s %s bytes\n' "$(basename "$f")" "$(/usr/bin/wc -c < "$f" 2>/dev/null || echo 0)"; done
  echo "======================================================="
} | tee "$MANIFEST"
echo "DIAG-INFO manifest -> $MANIFEST"
exit 0
