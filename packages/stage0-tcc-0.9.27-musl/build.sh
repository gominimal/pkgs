#!/usr/bin/env bash
# R4a PROBE — build the musl-RELINK tcc (GOT fix) with tcc-0.9.26, then link+RUN musl binaries on
# real amd64.  set +e / exit 0 -> always reports (build failures + run results captured in MANIFEST).
# No python (its glibc/toolchain graph bloats ncl-eval + won't run in a pure-bedrock env); diagnostics
# are run-rc counts + a custom-_start isolation (linker/codegen sound vs musl-startup crash).
set +e
set -u
BUILDROOT="$(pwd)"                       # Local files (tccsrc.tar.gz) live here
TCC26=/usr/bin/tcc-0.9.26                 # R2
OUTROOT=/build/output/usr/share/tcc-musl-probe
BINOUT=/build/output/usr/bin
WORK=/build/tm
LT=/build/tcclib                          # writable libtcc1 location the new tcc bakes
mkdir -p "$OUTROOT" "$BINOUT" "$WORK" "$LT"
MAN="$OUTROOT/MANIFEST.txt"
emit(){ echo "$1"; echo "$1" >> "$WORK/rows.txt"; }

emit "TM-INFO stage0-tcc-0.9.27-musl probe (FIXED tcc, [R5 amd64 static-GOT fix]) — CS real amd64"
emit "TM-INFO tcc-0.9.26: $($TCC26 -version 2>&1 | head -1)   musl crt: $(ls -la /usr/lib/crt1.o 2>/dev/null | awk '{print $5}')B   libc.a: $(ls -la /usr/lib/libc.a 2>/dev/null | awk '{print $5}')B"

# --- extract the R3-patched tcc source (incl. the GOT fix) ---
cd "$WORK"
# tarball is xattr-stripped (--no-xattrs at creation): macOS Sequoia stamps com.apple.provenance on every
# file -> PAX LIBARCHIVE.xattr headers that GNU tar in CS silently chokes on -> partial extract (rc=0!).
tar --no-same-owner -xzf "$BUILDROOT/tccsrc.tar.gz" 2>/tmp/te; xrc=$?
[ "$xrc" = 0 ] || emit "TM-FAIL extract: $(head -1 /tmp/te)"
cd tccsrc || { emit "TM-FAIL no tccsrc dir"; cp "$WORK/rows.txt" "$OUTROOT/rows.log"; echo "extract failed" | tee "$MAN"; cp "$TCC26" "$BINOUT/tcc-musl"; exit 0; }
emit "TM-INFO extracted $(ls | wc -l | tr -d ' ') files; tccelf.c $(test -f tccelf.c && echo present || echo MISSING)"
: > config.h
emit "TM-INFO GOT fix present: $(grep -c 'R5 amd64 static-GOT fix' tccelf.c)  (fill_got@$(grep -n 'fill_got(s1)' tccelf.c | head -1 | cut -d: -f1) tidy@$(grep -n 'tidy_section_headers(s1, sec_order)' tccelf.c | head -1 | cut -d: -f1))"

# --- build libtcc1.a (x86_64) with tcc-0.9.26 -> /build/tcclib ---
$TCC26 -c -D TCC_TARGET_X86_64=1 -o "$LT/libtcc1.o" lib/libtcc1.c 2>/tmp/l1
$TCC26 -c -D TCC_TARGET_X86_64=1 -o "$LT/va_list.o" lib/va_list.c 2>/tmp/l2
$TCC26 -ar cr "$LT/libtcc1.a" "$LT/libtcc1.o" "$LT/va_list.o" 2>/tmp/l3
emit "TM-LIBTCC1 libtcc1.a=$(ls -la $LT/libtcc1.a 2>/dev/null | awk '{print $5}')B (cc1: $(head -1 /tmp/l1))"

# --- build tcc-musl with tcc-0.9.26: MUSL prefixes baked.  tcc-0.9.26 is mes-linked -> arena lottery; retry. ---
TM=/build/tcc-musl
built=0
for i in 1 2 3 4 5 6 7 8; do
  rm -f "$TM"
  "$TCC26" -w -static -o "$TM" \
    -D TCC_TARGET_X86_64=1 \
    -D CONFIG_TCCDIR=\"/build/tcclib\" \
    -D CONFIG_TCC_CRTPREFIX=\"/usr/lib\" \
    -D CONFIG_TCC_LIBPATHS=\"/usr/lib:/build/tcclib\" \
    -D CONFIG_TCC_SYSINCLUDEPATHS=\"/usr/include\" \
    -D TCC_LIBGCC=\"/build/tcclib/libtcc1.a\" \
    -D CONFIG_TCC_STATIC=1 \
    -D CONFIG_USE_LIBGCC=1 \
    -D TCC_VERSION=\"0.9.27\" \
    -D ONE_SOURCE=1 \
    -I . -I /usr/include/mes \
    tcc.c 2>/tmp/be
  bc=$?
  [ -x "$TM" ] && { built=1; break; }
done
emit "TM-BUILD tcc-musl built=$built (try $i/8 last-rc=$bc be-bytes=$(wc -c </tmp/be | tr -d ' '))  $(test -x "$TM" && "$TM" -version 2>&1 | head -1)"
[ "$built" = 1 ] || emit "TM-BUILD-ERR: $(tail -4 /tmp/be 2>/dev/null | tr '\n' '|')"
if [ "$built" != 1 ]; then
  cp "$WORK/rows.txt" "$OUTROOT/rows.log"
  { echo "===== tcc-0.9.27-musl probe: FAILED to build tcc-musl (8 tries) ====="; grep -E "TM-" "$WORK/rows.txt"; } | tee "$MAN"
  cp "$TCC26" "$BINOUT/tcc-musl"; exit 0
fi
cp "$TM" "$BINOUT/tcc-musl"

# --- test programs ---
printf '#include <stdio.h>\nint main(void){ printf("MUSL-RUNS %%d\\n", 40+2); return 0; }\n' > hello.c
printf 'int main(void){ return 42; }\n' > ret42.c
"$TM" -nostdinc -I/usr/include -c -o hello.o hello.c 2>/tmp/ch; emit "TM-CC hello.o rc=$? $(head -1 /tmp/ch)"
"$TM" -nostdinc -c -o ret42.o ret42.c 2>/tmp/cr; emit "TM-CC ret42.o rc=$? $(head -1 /tmp/cr)"

cls(){ rc=$1; [ "$rc" = 0 ] && echo OK || { [ "$rc" -gt 128 ] 2>/dev/null && echo "CRASH($rc)" || echo "err($rc)"; }; }
# link a variant 6x (lottery) -> built/ran counts + run rc/output.  Each run is `timeout`-guarded so a
# hung binary can't wedge the build.
trial(){ L="$1"; shift; b=0; r=0; lastrc=0; out=""; runrc=""
  for i in 1 2 3 4 5 6; do
    rm -f h; "$@" -o h >/tmp/le 2>&1; lc=$?
    if [ "$lc" = 0 ]; then b=$((b+1)); timeout 10 ./h >/tmp/lo 2>&1; rc=$?; runrc="$rc"; [ "$rc" = 0 ] && r=$((r+1)); out="$(head -1 /tmp/lo)"; fi
    lastrc=$lc
  done
  emit "TM-LINK $L : built $b/6 ran-OK $r/6 (lastlink=$(cls $lastrc) runrc=$runrc) run='${out}'  $([ "$b" -gt 0 ] || head -1 /tmp/le)"
}

emit "TM-INFO ===== THE TEST: does the FIXED tcc link a RUNNING musl binary on real amd64? ====="
trial "ret42 auto-static"  "$TM" -static ret42.o
trial "ret42 explicit"     "$TM" -nostdlib -static /usr/lib/crt1.o /usr/lib/crti.o ret42.o /usr/lib/libc.a "$LT/libtcc1.a" /usr/lib/libc.a /usr/lib/crtn.o
trial "hello explicit"     "$TM" -nostdlib -static /usr/lib/crt1.o /usr/lib/crti.o hello.o /usr/lib/libc.a "$LT/libtcc1.a" /usr/lib/libc.a /usr/lib/crtn.o

# --- LAYER ISOLATION: custom _start that calls main DIRECTLY (skips musl crt1/__libc_start_main/__init_tls).
# Unconfounded on real amd64 (no Rosetta bss quirk).  If this RUNS but full-musl segfaults -> the crash is
# in musl's startup (layer 2), and the linker+GOT+codegen are sound.  If this also segfaults -> layer 1. ---
cat > cs.c <<'CC'
__asm__(".global _start\n_start:\n xorq %rbp,%rbp\n movq %rsp,%rdi\n andq $-16,%rsp\n call mystart_c\n");
extern int main(int,char**,char**);
void mystart_c(long*sp){ int r=main((int)sp[0],(char**)(sp+1),(char**)(sp+1)+sp[0]+1);
  __asm__ volatile("movl %0,%%edi\n movq $60,%%rax\n syscall"::"r"(r):"rax"); }
int __padbss[2048];
CC
"$TM" -nostdinc -c -o cs.o cs.c 2>/tmp/ccs; emit "TM-CC cs.o(custom _start) rc=$? $(head -1 /tmp/ccs)"
trial "CUSTOM-start (no musl startup)" "$TM" -nostdlib -static cs.o ret42.o

cp "$WORK/rows.txt" "$OUTROOT/rows.log"
{
  echo "============ stage0-tcc-0.9.27-musl PROBE (FIXED tcc, GOT fix) — CS real amd64 ============"
  grep -E "TM-" "$WORK/rows.txt"
  echo "-------------------------------------------------------------------------------------------"
  echo "READ: 'ret42/hello explicit' ran-OK>0  -> GOT fix WORKS on real amd64 -> the segfault was Rosetta,"
  echo "      R5 (binutils via tcc-musl) is unblocked.  built>0 ran-OK=0 -> REAL crash on amd64 (layer 2)."
  echo "      'CUSTOM-start' ran-OK>0 while full-musl=0  -> crash is in musl startup, linker/codegen SOUND."
  echo "==========================================================================================="
} | tee "$MAN"
exit 0
