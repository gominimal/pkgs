#!/usr/bin/env bash
# musl-crt-diag v23 — R5 LINKING CANARY (CS ground truth). The local Rosetta harness says tcc-0.9.27's
# static linker DETERMINISTICALLY SIGSEGVs linking R4-musl's crt1.o (which carries R_X86_64_GOTPCREL/PLT32
# relocs that mes objects never use), while mes links fine. BUT emulation misled us badly twice this
# session (both directions), so this probe runs the SAME test IN the CS sandbox (real amd64) to decide
# whether the GOTPCREL link wall is real or an emulation artifact. R4 (sealed musl) is a dep, so its
# crt+libc are at /usr/lib and headers at /usr/include; R3 mes is at /usr/lib/mes. set +e, exit 0.
set +e
set -u
TCC=/usr/bin/tcc
OUTROOT=/build/output/usr/share/musl-crt-diag; WORK=/build/diag
mkdir -p "$OUTROOT" "$WORK"; MANIFEST="$OUTROOT/MANIFEST.txt"
emit(){ echo "$1"; echo "$1" >> "$WORK/rows.txt"; }
emit "DIAG-INFO musl-crt-diag v23 R5-LINK-CANARY — $("$TCC" -version 2>&1 | head -1)"
cd "$WORK"
ME=/usr/lib/mes
printf '#include <stdio.h>\nint main(void){ printf("CANARY-OK\\n"); return 0; }\n' > hello.c

# what's actually present?
emit "DIAG-ENV musl crt: $(ls -la /usr/lib/crt1.o 2>/dev/null | awk '{print $5}')B  musl libc.a: $(ls -la /usr/lib/libc.a 2>/dev/null | awk '{print $5}')B  mes crt: $(ls -la $ME/crt1.o 2>/dev/null | awk '{print $5}')B"
emit "DIAG-ENV musl stdio.h: $(test -f /usr/include/stdio.h && echo yes || echo NO)  libtcc1: $(test -f $ME/tcc/libtcc1.a && echo yes || echo NO)"

# compile hello.o once with musl headers
"$TCC" -nostdinc -I/usr/include -c -o hello.o hello.c >/tmp/ce 2>&1
emit "DIAG-CC compile hello.o (musl hdr) rc=$? $(head -1 /tmp/ce)"

cls(){ rc=$1; [ "$rc" = 0 ] && echo OK || { [ "$rc" -gt 128 ] 2>/dev/null && echo "CRASH($rc)" || echo "err($rc)"; }; }
# link a variant N times; report built/N and (if built) run-rc
trial(){ # $1=label  $2..=link cmd
  L="$1"; shift; b=0; r=0; lastrc=0; runout=""
  for i in 1 2 3 4 5 6; do
    rm -f h 2>/dev/null; "$@" -o h >/tmp/le 2>&1; lc=$?
    [ "$lc" = 0 ] && { b=$((b+1)); ./h >/tmp/lo 2>&1; rc=$?; [ "$rc" = 0 ] && r=$((r+1)); runout="$(head -1 /tmp/lo)"; }
    lastrc=$lc
  done
  emit "DIAG-LINK $L : built $b/6  ran-OK $r/6  (lastlink=$(cls $lastrc) $(head -1 /tmp/le))  run='${runout}'"
}

emit "DIAG-INFO ===== link variants (the decisive R5 question) ====="
# C control: baked mes (compile+link in one shot) — expect built, run-fail (mes ABI != musl hdr)
trial "C  baked-mes"            "$TCC" -nostdinc -I/usr/include -static hello.c
# K control: explicit mes everything — expect built+ran (mes self-consistent, but mes printf)
trial "K  explicit-mes"         "$TCC" -nostdlib -static $ME/crt1.o $ME/crti.o hello.o $ME/libc.a $ME/tcc/libtcc1.a $ME/crtn.o
# I THE TEST: explicit MUSL crt + libc — expect built+ran 'CANARY-OK' IF the wall is emulation-only
trial "I  explicit-MUSL"        "$TCC" -nostdlib -static /usr/lib/crt1.o /usr/lib/crti.o hello.o /usr/lib/libc.a $ME/tcc/libtcc1.a /usr/lib/crtn.o
# J the reducer: just musl crt1.o (no libc) — local 0/6; is the linker crash present in CS?
trial "J  musl-crt1-only"       "$TCC" -nostdlib -static /usr/lib/crt1.o hello.o
# G/H isolation: which musl half crashes (crt vs libc)
trial "G  musl-crt + mes-libc"  "$TCC" -nostdlib -static /usr/lib/crt1.o /usr/lib/crti.o hello.o $ME/libc.a $ME/tcc/libtcc1.a /usr/lib/crtn.o
trial "H  mes-crt + musl-libc"  "$TCC" -nostdlib -static $ME/crt1.o $ME/crti.o hello.o /usr/lib/libc.a $ME/tcc/libtcc1.a $ME/crtn.o

cp "$WORK/rows.txt" "$OUTROOT/rows.txt.log" 2>/dev/null
cp "$TCC" "$OUTROOT/tcc-0.9.27" 2>/dev/null   # satisfy build.ncl's `binaries` output glob (else build fails)
{
  echo "============ musl-crt-diag v23 R5-LINK-CANARY (CS real amd64) ============"
  grep -E "DIAG-ENV|DIAG-CC|DIAG-LINK" "$WORK/rows.txt" 2>/dev/null
  echo "READ: if 'I explicit-MUSL' shows ran-OK>0 'CANARY-OK', the GOTPCREL wall was EMULATION-only -> R5"
  echo "      links musl fine in CS. If I built 0/6 like local, the tcc static-linker GOTPCREL bug is REAL"
  echo "      (fix = tcc tccelf.c patch -> R3 re-seal, OR a musl-linked tcc pass2). G vs H isolates crt vs libc."
  echo "========================================================================="
} | tee "$MANIFEST"
exit 0
