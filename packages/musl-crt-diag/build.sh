#!/usr/bin/env bash
# musl-crt-diag v20 — REDUCE __init_tls (the last R4 blocker) ON REAL amd64 (the CS sandbox). It SIGSEGVs
# 20/20 in CS but 0/10 under local Rosetta emulation with the SAME sealed tcc -> a real-HW-deterministic
# tcc bug (uninitialized-mem / platform-sensitive codegen) masked by emulation. This probe runs IN the CS
# builder (real amd64) so the crash reproduces, then build-downs __init_tls.i to pin the construct:
#   (a) confirm __init_tls.c + the preprocessed __init_tls.i both crash (self-contained reducer).
#   (b) prefix-bisect __init_tls.i: smallest head -N that SIGSEGVs => the crashing line + context.
#   (c) which #include alone crashes (elf.h / sys/mman.h / pthread_impl.h ...).
# set +e, exit 0, OutputData.
set +e
set -u
TCC=/usr/bin/tcc
VERSION="${MINIMAL_ARG_VERSION:-1.1.24}"
SRC="musl-${VERSION}"; BUILDROOT="$(pwd)"
OUTROOT=/build/output/usr/share/musl-crt-diag; WORK=/build/diag
mkdir -p "$OUTROOT" "$WORK"; MANIFEST="$OUTROOT/MANIFEST.txt"
emit(){ echo "$1"; echo "$1" >> "$WORK/rows.txt"; }
emit "DIAG-INFO musl-crt-diag v20 INITTLS-REDUCE (real amd64) — $("$TCC" -version 2>&1 | head -1)"
tar -xf "${SRC}.tar.gz" 2>/dev/null; cd "${SRC}" || { emit FATAL; exit 0; }
for p in makefile madvise_preserve_errno avoid_sys_clone disable_ctype_headers skip-pic-crt drop-dynamic-crt amd64-va-list amd64-syscall-arch; do
  patch -Np1 -i "${BUILDROOT}/${p}.patch" >/dev/null 2>&1
done
rm src/ctype/iswalpha.c src/ctype/iswalnum.c src/ctype/iswctype.c src/ctype/towctrans.c 2>/dev/null
rm include/iconv.h src/locale/iconv.c src/locale/iconv_close.c 2>/dev/null; rm -rf src/complex 2>/dev/null
CC=tcc ./configure --host=x86_64 --disable-shared --prefix=/usr --libdir=/usr/lib --includedir=/usr/include >/dev/null 2>&1
make obj/include/bits/alltypes.h obj/include/bits/syscall.h >/dev/null 2>&1
# v22: -Werror REFUTED (v21: all combos OK in the probe). The crash is INVOCATION-CONTEXT sensitive — the
# only delta vs the real `make` is the -o PATH / cwd / env layout (mes-libc arena, ASLR-off-deterministic).
# Reproduce via the EXACT make -o path, then sweep perturbations to find what lands it.
MK="-std=c99 -nostdinc -ffreestanding -fexcess-precision=standard -frounding-math -Wa,--noexecstack -D_XOPEN_SOURCE=700 -I./arch/x86_64 -I./arch/generic -Iobj/src/internal -I./src/include -I./src/internal -Iobj/include -I./include -Os -pipe -fomit-frame-pointer -fno-unwind-tables -fno-asynchronous-unwind-tables -ffunction-sections -fdata-sections -Werror=implicit-function-declaration -Werror=implicit-int -Werror=pointer-sign -Werror=pointer-arith -DSYSCALL_NO_TLS -w -fno-stack-protector"
cls(){ rc=$1; if [ "$rc" = 0 ]; then echo OK; elif [ "$rc" -gt 128 ] 2>/dev/null; then echo "CRASH(rc=$rc)"; else echo "err(rc=$rc)"; fi; }
F=src/env/__init_tls.c
mkdir -p obj/src/env

# REPRO: the EXACT make -o path, from the musl cwd
"$TCC" $MK -c -o obj/src/env/__init_tls.o "$F" >/dev/null 2>&1; emit "DIAG-RC repro: -o obj/src/env/__init_tls.o (make's exact path) -> $(cls $?)"
# control: a short /tmp -o path
"$TCC" $MK -c -o /tmp/o "$F" >/dev/null 2>&1; emit "DIAG-RC ctrl : -o /tmp/o (short path)               -> $(cls $?)"

# PERTURB sweep 1: env padding lengths (shifts the argv/env stack block -> stack-top layout)
emit "DIAG-INFO ===== env-padding sweep (-o = make's exact path) ====="
firstpad=-1
for n in 0 1 2 4 8 16 24 32 48 64 96 128 192 256 384 512 768 1024 2048 4096; do
  PAD=$(awk "BEGIN{for(i=0;i<$n;i++)printf \"x\"}")
  env _MESPAD="$PAD" "$TCC" $MK -c -o obj/src/env/__init_tls.o "$F" >/dev/null 2>&1; rc=$?
  st=$(cls $rc); emit "DIAG-PAD env _MESPAD len=$n -> $st"
  [ "$rc" = 0 ] && [ "$firstpad" = -1 ] && { firstpad=$n; cp obj/src/env/__init_tls.o "$WORK/pad-$n.o"; }
done
emit "DIAG-INFO first landing env-pad length = $firstpad"

# PERTURB sweep 2: -o path LENGTH (the -o string sits in argv -> shifts early malloc/stack layout)
emit "DIAG-INFO ===== -o path-length sweep ====="
firstlen=-1
for n in 0 4 8 16 32 64 128 200; do
  pad=$(awk "BEGIN{for(i=0;i<$n;i++)printf \"p\"}")
  op="obj/src/env/${pad}__init_tls.o"
  "$TCC" $MK -c -o "$op" "$F" >/dev/null 2>&1; rc=$?
  st=$(cls $rc); emit "DIAG-OPLEN -o pad=$n -> $st"
  [ "$rc" = 0 ] && [ "$firstlen" = -1 ] && { firstlen=$n; cp "$op" "$WORK/oplen-$n.o" 2>/dev/null; }
done
emit "DIAG-INFO first landing -o pad length = $firstlen"

# byte-identity check: do two DIFFERENT successful perturbations produce the SAME .o?
S1=$(sha256sum "$WORK"/pad-*.o 2>/dev/null | head -1 | cut -d' ' -f1)
S2=$(sha256sum "$WORK"/oplen-*.o 2>/dev/null | head -1 | cut -d' ' -f1)
emit "DIAG-SHA pad-success .o sha=$S1"
emit "DIAG-SHA oplen-success .o sha=$S2"
[ -n "$S1" ] && [ "$S1" = "$S2" ] && emit "DIAG-SHA -> IDENTICAL across perturbations (seal-safe)"

cp "$WORK/rows.txt" "$OUTROOT/rows.txt.log" 2>/dev/null
cp "$WORK/it.i" "$OUTROOT/init_tls.i.log" 2>/dev/null
cp "$TCC" "$OUTROOT/tcc-0.9.27" 2>/dev/null
{
  echo "============ musl-crt-diag v22 LAYOUT-PERTURB (real amd64) ============"
  grep -E "DIAG-RC|DIAG-PAD|DIAG-OPLEN|DIAG-SHA|first landing" "$WORK/rows.txt" 2>/dev/null
  echo "READ: if repro=CRASH and some pad/oplen=OK, a PERTURBING retry wrapper cures R4 (seal-safe if SHA identical)."
  echo "======================================================================"
} | tee "$MANIFEST"
exit 0
