#!/usr/bin/env bash
# R4a STAGE 2 — THE VERDICT. Run s1's GOT-fixed tcc-musl against R4 musl (clean musl env, no R1).
set +e
set -u
TM=/usr/bin/tcc-musl
LT=/usr/lib/tcc/libtcc1.a
LOGOUT=/build/output/usr/share/tcc-musl-s2
mkdir -p "$LOGOUT" /build/tm
MAN="$LOGOUT/MANIFEST.txt"
emit(){ echo "$1"; echo "$1" >> /build/tm/rows.txt; }

emit "S2-INFO test GOT-fixed tcc-musl vs R4 musl — tcc-musl: $("$TM" -version 2>&1 | head -1)"
emit "S2-INFO libtcc1: $(ls -la $LT 2>/dev/null | awk '{print $5}')B  musl crt1.o: $(ls -la /usr/lib/crt1.o 2>/dev/null | awk '{print $5}')B  libc.a: $(ls -la /usr/lib/libc.a 2>/dev/null | awk '{print $5}')B  stdio.h: $(test -f /usr/include/stdio.h && echo yes || echo NO)"

cd /build/tm
printf '#include <stdio.h>\nint main(void){ printf("MUSL-RUNS %%d\\n", 40+2); return 0; }\n' > hello.c
printf 'int main(void){ return 42; }\n' > ret42.c
"$TM" -nostdinc -I/usr/include -c -o hello.o hello.c 2>/tmp/ch; emit "S2-CC hello.o rc=$? $(head -1 /tmp/ch)"
"$TM" -nostdinc -c -o ret42.o ret42.c 2>/tmp/cr; emit "S2-CC ret42.o rc=$? $(head -1 /tmp/cr)"

cls(){ rc=$1; [ "$rc" = 0 ] && echo OK || { [ "$rc" -gt 128 ] 2>/dev/null && echo "CRASH($rc)" || echo "err($rc)"; }; }
trial(){ L="$1"; shift; b=0; r=0; lastrc=0; out=""; runrc=""
  for i in 1 2 3 4 5 6 7 8; do
    rm -f h; "$@" -o h >/tmp/le 2>&1; lc=$?
    if [ "$lc" = 0 ]; then b=$((b+1)); timeout 10 ./h >/tmp/lo 2>&1; rc=$?; runrc="$rc"; [ "$rc" = 0 ] && r=$((r+1)); out="$(head -1 /tmp/lo)"; fi
    lastrc=$lc
  done
  emit "S2-LINK $L : built $b/8 ran-OK $r/8 (lastlink=$(cls $lastrc) runrc=$runrc) run='${out}'  $([ "$b" -gt 0 ] || head -1 /tmp/le)"
}

emit "S2-INFO ===== THE TEST: does the GOT-fixed tcc-musl link a RUNNING musl binary on real amd64? ====="
trial "ret42 auto-static"  "$TM" -static ret42.o
trial "ret42 explicit"     "$TM" -nostdlib -static /usr/lib/crt1.o /usr/lib/crti.o ret42.o /usr/lib/libc.a "$LT" /usr/lib/libc.a /usr/lib/crtn.o
trial "hello explicit"     "$TM" -nostdlib -static /usr/lib/crt1.o /usr/lib/crti.o hello.o /usr/lib/libc.a "$LT" /usr/lib/libc.a /usr/lib/crtn.o

# layer-2 isolation: custom _start -> main directly (skip musl crt1/__libc_start_main/__init_tls).
# Unconfounded on real amd64. Runs while full-musl segfaults => crash is musl startup, linker/GOT sound.
cat > cs.c <<'CC'
__asm__(".global _start\n_start:\n xorq %rbp,%rbp\n movq %rsp,%rdi\n andq $-16,%rsp\n call mystart_c\n");
extern int main(int,char**,char**);
void mystart_c(long*sp){ int r=main((int)sp[0],(char**)(sp+1),(char**)(sp+1)+sp[0]+1);
  __asm__ volatile("movl %0,%%edi\n movq $60,%%rax\n syscall"::"r"(r):"rax"); }
int __padbss[2048];
CC
"$TM" -nostdinc -c -o cs.o cs.c 2>/tmp/ccs; emit "S2-CC cs.o(custom _start) rc=$? $(head -1 /tmp/ccs)"
trial "CUSTOM-start (no musl startup)" "$TM" -nostdlib -static cs.o ret42.o

cp /build/tm/rows.txt "$LOGOUT/rows.log"
{
  echo "============ stage0-tcc-0.9.27-musl-s2 VERDICT (GOT fix on real amd64) ============"
  grep "S2-" /build/tm/rows.txt
  echo "------------------------------------------------------------------------------------"
  echo "READ: 'ret42/hello explicit' ran-OK>0 => GOT fix WORKS on real amd64 => the segfault was Rosetta,"
  echo "      R5 (binutils via a musl-relinked tcc) is unblocked.  built>0 ran-OK=0 => REAL layer-2 crash."
  echo "      'CUSTOM-start' ran-OK>0 while full-musl=0 => crash is musl startup; linker/GOT/codegen SOUND."
} | tee "$MAN"
exit 0
