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

# ── PHASE 0 (R5 SWEEP): localize the mes-tcc lottery determinant — env/argv-seeded stack layout? ──
# Reproduce s1's tcc.c compile (s1's MUSL DEFS, ONE_SOURCE=1) under (a) ambient env [the control], (b)
# fully-cleared env, (c) a swept env-block length (PAD=k×'A'), to DISCOVER whether the per-sandbox
# rc=139 SIGSEGV tracks the process initial-stack offset (argv+envp length). OPEN probe: MEASURE only —
# every roll prints rc + objbytes; bakes NOTHING into any rung; set +e; falls straight through to exit 0.
emit "DIAG-INFO ===== (0) R5 env+stack-PAD sweep ====="
SW_TCC=/usr/bin/tcc-0.9.26
SWEEPDIR=/build/sweep; mkdir -p "$SWEEPDIR"
cd "/build/$TCC_PKG" || emit "SWEEP-FAIL no /build/$TCC_PKG source dir"
: > config.h                          # tcc.c #includes "config.h"; s1 does the same (empty)
# s1's EXACT compile flags (MUSL prefixes, from stage0-tcc-0.9.27-musl-s1/build.sh DEFS+INCS);
# ONE_SOURCE=1 for the reliable full-tcc.c crasher (the primary unit).
SW_DEFS=(
  -D TCC_TARGET_X86_64=1
  -D 'CONFIG_TCCDIR="/usr/lib/tcc"' -D 'CONFIG_TCC_CRTPREFIX="/usr/lib"'
  -D 'CONFIG_TCC_ELFINTERP="/mes/loader"' -D 'CONFIG_TCC_LIBPATHS="/usr/lib:/usr/lib/tcc"'
  -D 'CONFIG_TCC_SYSINCLUDEPATHS="/usr/include"' -D 'TCC_LIBGCC="/usr/lib/tcc/libtcc1.a"'
  -D CONFIG_TCC_STATIC=1 -D CONFIG_USE_LIBGCC=1 -D 'TCC_VERSION="0.9.27PW2"'
)
SW_INCS=(-I . -I /usr/include -I /usr/include/mes)
SW_OUT=/tmp/sw.o
SW_ARGS=(-w -c -o "$SW_OUT" "${SW_DEFS[@]}" -D ONE_SOURCE=1 "${SW_INCS[@]}" tcc.c)      # primary  unit
SW_TG_ARGS=(-w -c -o "$SW_OUT" "${SW_DEFS[@]}" -D ONE_SOURCE=0 "${SW_INCS[@]}" tccgen.c) # secondary unit

# (1) CAPTURE the load-bearing-but-uncited premises: the ambient env, the EXACT argv, the search-dirs.
emit "SWEEP-CAP env:"
env | sort | while IFS= read -r ln; do emit "SWEEP-CAP env| $ln"; done
emit "SWEEP-CAP argv: $SW_TCC ${SW_ARGS[*]}"
emit "SWEEP-CAP search-dirs:"
"$SW_TCC" -print-search-dirs 2>&1 | while IFS= read -r ln; do emit "SWEEP-CAP sdir| $ln"; done

# (2) MATRIX: one config = one initial-stack env layout; reps expose per-exec stability within THIS
# sandbox. rc is timeout's verdict (139=SIGSEGV, 124=timeout, else tcc's rc); objbytes = output .o size.
SW_CURARGS=("${SW_ARGS[@]}")
sw_run(){ local cfg="$1" reps="$2"; shift 2      # remaining args = optional env-clearing prefix (env -i …)
  local r rc ob
  for r in $(seq 1 "$reps"); do
    rm -f "$SW_OUT"
    timeout 180 "$@" "$SW_TCC" "${SW_CURARGS[@]}" >/dev/null 2>>"$SWEEPDIR/$cfg.err"; rc=$?
    ob=0; [ -f "$SW_OUT" ] && ob=$(/usr/bin/wc -c < "$SW_OUT" 2>/dev/null | tr -d ' ')
    emit "SWEEP $cfg rep$r rc=$rc objbytes=$ob"
  done
}
sw_run C0 3                                                   # ambient env — the control (MUST crash here)
sw_run C1 3 /usr/bin/env -i PATH=/usr/bin TMPDIR=/tmp         # fully-cleared env
for k in 0 8 16 32 64 128 256 512 1024; do                   # sweep stack offset via env-block length
  pad=$(head -c "$k" </dev/zero | tr '\0' A)
  sw_run "PAD$k" 3 /usr/bin/env -i PATH=/usr/bin TMPDIR=/tmp "PAD=$pad"
done
# (2b) secondary size-independence re-check on tccgen.c alone (1 rep ambient + 1 rep cleared).
SW_CURARGS=("${SW_TG_ARGS[@]}")
sw_run tccgen-C0 1
sw_run tccgen-C1 1 /usr/bin/env -i PATH=/usr/bin TMPDIR=/tmp
rm -f "$SW_OUT"
emit "SWEEP-DONE C0=ambient C1=cleared PAD{0,8,16,32,64,128,256,512,1024}=env-len sweep (×3 reps); tccgen ×1"

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

# ── PHASE 5: HEADER LAYOUT RECON — is /usr/include mes or glibc? where are mes's headers? ──
emit "DIAG-INFO ===== (c) header layout recon ====="
emit "DIAG-HDR /usr/include top-level .h count: $(ls /usr/include/*.h 2>/dev/null | /usr/bin/wc -l)"
emit "DIAG-HDR /usr/include/mes .h count: $(ls /usr/include/mes/*.h 2>/dev/null | /usr/bin/wc -l)"
emit "DIAG-HDR /usr/include/stdlib.h is: $(grep -qiE 'GNU Mes|__MES' /usr/include/stdlib.h 2>/dev/null && echo MES || echo GLIBC/other)"
emit "DIAG-HDR /usr/include/unistd.h is: $(grep -qiE 'GNU Mes|SYSTEM_LIBC|__MES_UNISTD' /usr/include/unistd.h 2>/dev/null && echo MES || echo GLIBC)"
emit "DIAG-HDR /usr/include/mes/stdlib.h exists: $([ -f /usr/include/mes/stdlib.h ] && echo YES || echo NO)"
emit "DIAG-HDR /usr/include/mes/unistd.h exists: $([ -f /usr/include/mes/unistd.h ] && echo YES || echo NO)"
emit "DIAG-HDR features-time64.h (modern-glibc marker): $([ -f /usr/include/features-time64.h ] && echo PRESENT=glibc-leak || echo absent)"
emit "DIAG-HDR where does <stdlib.h> live? $(ls -d /usr/include/stdlib.h /usr/include/mes/stdlib.h 2>/dev/null | tr '\n' ' ')"

# ── PHASE 6: FIX-TEST — compile tcc.c with candidate include configs; which one COMPILES clean? ──
# The crash is glibc's unistd.h chain. Test mes-header-preferring configs. The -D set matches R3.
emit "DIAG-INFO ===== (d) fix-test: which -I config compiles tcc.c? ====="
DBASE=( -D TCC_TARGET_X86_64=1 -D "CONFIG_TCCDIR=\"/usr/lib/mes/tcc\"" -D "CONFIG_TCC_CRTPREFIX=\"/usr/lib/mes\"" \
  -D "CONFIG_TCC_ELFINTERP=\"/mes/loader\"" -D "CONFIG_TCC_LIBPATHS=\"/usr/lib/mes:/usr/lib/mes/tcc\"" \
  -D "CONFIG_TCC_SYSINCLUDEPATHS=\"/usr/include/mes\"" -D "TCC_LIBGCC=\"/usr/lib/mes/libc.a\"" \
  -D CONFIG_TCC_STATIC=1 -D CONFIG_USE_LIBGCC=1 -D "TCC_VERSION=\"0.9.27\"" -D ONE_SOURCE=1 )
testcfg(){ local lab="$1"; shift
  ( cd "/build/$TCC_PKG" && timeout 150 "$TCC" -w -c -o "$WORK/t-$lab.o" "${DBASE[@]}" "$@" tcc.c ) >"$WORK/cfg-$lab.out" 2>&1
  local rc=$?
  emit "DIAG-FIX [$lab] rc=$rc ($([ -s "$WORK/t-$lab.o" ] && echo OBJ-OK || echo NO-OBJ)) args='$*' >>> $(tail -2 "$WORK/cfg-$lab.out" 2>/dev/null | tr '\n' '|')"
}
testcfg mesonly     -I . -I /usr/include/mes
testcfg mesfirst    -I . -I /usr/include/mes -I /usr/include
testcfg glibc-repro -I . -I /usr/include -I /usr/include/mes
emit "DIAG-FIX INTERPRET: a 'mesonly'/'mesfirst' OBJ-OK while 'glibc-repro' crashes => the fix is to"
emit "DIAG-FIX   prefer mes headers in R3's tcc.c compile (and it's a hermeticity win — no host glibc)."

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
  echo "ARTIFACTS (gs://minimalmertic-sign-staging/tcc-0.9.27-diag-1.1-a/usr/share/tcc-0.9.27-diag/):"
  for f in "$OUTROOT"/*; do [ "$f" = "$MANIFEST" ] && continue; printf '  %-26s %s bytes\n' "$(basename "$f")" "$(/usr/bin/wc -c < "$f" 2>/dev/null || echo 0)"; done
  echo "======================================================="
} | tee "$MANIFEST"
echo "DIAG-INFO manifest -> $MANIFEST"
exit 0
