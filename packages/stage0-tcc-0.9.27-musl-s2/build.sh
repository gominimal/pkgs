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

# BARE-exit: _start -> exit(42) syscall, NO C, NO main, NO GOT. Isolates asm+ELF-format+loading from C
# codegen. If this RUNS (rc=42) but CUSTOM/full-musl crash -> the bug is C codegen / startup, format sound.
cat > bare.c <<'CC'
__asm__(".global _start\n_start:\n movl $42,%edi\n movl $60,%eax\n syscall\n");
CC
"$TM" -nostdinc -c -o bare.o bare.c 2>/tmp/cb; emit "S2-CC bare.o rc=$? $(head -1 /tmp/cb)"
trial "BARE-exit (asm+format only)" "$TM" -nostdlib -static bare.o
# DATA-ref: main returns a global int (tests static data reloc + codegen, no startup/asm)
cat > dref.c <<'CC'
int g = 42;
__asm__(".global _start\n_start:\n call get\n movl %eax,%edi\n movl $60,%eax\n syscall\n");
int get(void){ return g; }
CC
"$TM" -nostdinc -c -o dref.o dref.c 2>/tmp/cd; emit "S2-CC dref.o rc=$? $(head -1 /tmp/cd)"
trial "DATA-ref (global int via call)" "$TM" -nostdlib -static dref.o
# 3ARG: a 3-arg C call (like main(argc,argv,envp)). exit code = 1+2+20=23 if 3-arg passing is correct.
cat > a3.c <<'CC'
__asm__(".global _start\n_start:\n movl $1,%edi\n movl $2,%esi\n movl $20,%edx\n call add3\n movl %eax,%edi\n movl $60,%eax\n syscall\n");
int add3(int a,int b,int c){ return a+b+c; }
CC
"$TM" -nostdinc -c -o a3.o a3.c 2>/tmp/c3; emit "S2-CC a3.o rc=$? $(head -1 /tmp/c3)"
trial "3ARG-call (expect rc=23)" "$TM" -nostdlib -static a3.o
# STACKREAD: read argc off the stack pointer (like _start reading rsp). exit code = argc (>=1).
cat > sr.c <<'CC'
__asm__(".global _start\n_start:\n movq %rsp,%rdi\n call rd\n movl %eax,%edi\n movl $60,%eax\n syscall\n");
int rd(long*p){ return (int)p[0]; }
CC
"$TM" -nostdinc -c -o sr.o sr.c 2>/tmp/csr; emit "S2-CC sr.o rc=$? $(head -1 /tmp/csr)"
trial "STACKREAD (expect rc=argc>=1)" "$TM" -nostdlib -static sr.o
# XOBJ: clean CROSS-OBJECT call — _start (xa.o) calls f() defined in xb.o. CUSTOM-start's distinguishing
# feature vs the working same-object tests. exit code = 42 if cross-object call reloc is correct.
cat > xa.c <<'CC'
extern int f(void);
__asm__(".global _start\n_start:\n call f\n movl %eax,%edi\n movl $60,%eax\n syscall\n");
CC
printf 'int f(void){ return 42; }\n' > xb.c
"$TM" -nostdinc -c -o xa.o xa.c 2>/tmp/cxa; "$TM" -nostdinc -c -o xb.o xb.c 2>/tmp/cxb
emit "S2-CC xa.o rc=? xb.o rc=? $(head -1 /tmp/cxa)$(head -1 /tmp/cxb)"
trial "XOBJ-call (f in separate object, expect rc=42)" "$TM" -nostdlib -static xa.o xb.o
# ASMINPUT: function-local inline-asm with an "r" INPUT operand (%0). Unique to mystart_c vs the working
# tests; musl's syscall wrappers use the same. If this crashes -> tcc-musl operand-substitution codegen bug.
cat > ai.c <<'CC'
void g(void){ int v=42; __asm__ volatile("movl %0,%%edi\n movl $60,%%eax\n syscall"::"r"(v):"eax"); }
__asm__(".global _start\n_start:\n call g\n");
CC
"$TM" -nostdinc -c -o ai.o ai.c 2>/tmp/cai; emit "S2-CC ai.o rc=$? $(head -1 /tmp/cai)"
trial "ASMINPUT (inline-asm \"r\" operand, expect rc=42)" "$TM" -nostdlib -static ai.o
# COMPUTEDARG: read sp[0] then pass a COMPUTED value as a call arg (mystart_c's other unique bit).
cat > ca.c <<'CC'
int id(int x){ return x; }
int h(long*sp){ return id((int)sp[0] + 10); }
__asm__(".global _start\n_start:\n movq %rsp,%rdi\n call h\n movl %eax,%edi\n movl $60,%eax\n syscall\n");
CC
"$TM" -nostdinc -c -o ca.o ca.c 2>/tmp/cca; emit "S2-CC ca.o rc=$? $(head -1 /tmp/cca)"
trial "COMPUTEDARG (sp[0]+10 via call, expect rc=11)" "$TM" -nostdlib -static ca.o

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
