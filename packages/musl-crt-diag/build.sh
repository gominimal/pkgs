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
# the EXACT real flags for __init_tls.o (incl -fno-stack-protector)
FULL="-std=c99 -nostdinc -ffreestanding -fexcess-precision=standard -frounding-math -Wa,--noexecstack -D_XOPEN_SOURCE=700 -I./arch/x86_64 -I./arch/generic -Iobj/src/internal -I./src/include -I./src/internal -Iobj/include -I./include -Os -pipe -fomit-frame-pointer -fno-unwind-tables -fno-asynchronous-unwind-tables -ffunction-sections -fdata-sections -DSYSCALL_NO_TLS -w -fno-stack-protector"
cls(){ rc=$1; if [ "$rc" = 0 ]; then echo OK; elif [ "$rc" -gt 128 ] 2>/dev/null; then echo "CRASH(rc=$rc)"; else echo "err(rc=$rc)"; fi; }
F=src/env/__init_tls.c

# What CS configure actually produced (does it add -Werror? local emulation did NOT):
emit "DIAG-CFG CFLAGS_AUTO = $(grep -E '^CFLAGS_AUTO' config.mak 2>/dev/null | head -1)"
WERR="-Werror=implicit-function-declaration -Werror=implicit-int -Werror=pointer-sign -Werror=pointer-arith"

# (a) baseline: no -Werror (= my v20 probe; was OK)
"$TCC" $FULL -c -o "$WORK/it.o" "$F" >"$WORK/a.err" 2>&1; emit "DIAG-IT (a) NO -Werror        -> $(cls $?)"
# (b) the REAL make flags: WITH all 4 -Werror (hypothesis: CRASH)
"$TCC" $FULL $WERR -c -o "$WORK/it.o" "$F" >"$WORK/b.err" 2>&1; emit "DIAG-IT (b) +ALL -Werror     -> $(cls $?)   diag:$(head -1 "$WORK/b.err")"
# (c) isolate WHICH -Werror crashes
for w in implicit-function-declaration implicit-int pointer-sign pointer-arith; do
  "$TCC" $FULL -Werror=$w -c -o "$WORK/it.o" "$F" >"$WORK/w.err" 2>&1
  emit "DIAG-IT (c) only -Werror=$w -> $(cls $?)   diag:$(head -1 "$WORK/w.err")"
done
# (d) THE FIX: real make flags but -Werror stripped (hypothesis: OK). Proves the build.sh sed.
"$TCC" $FULL -c -o "$WORK/it.o" "$F" >/dev/null 2>&1; emit "DIAG-IT (d) -Werror STRIPPED   -> $(cls $?)  [= the R4 fix]"

cp "$WORK/rows.txt" "$OUTROOT/rows.txt.log" 2>/dev/null
cp "$WORK/it.i" "$OUTROOT/init_tls.i.log" 2>/dev/null
cp "$TCC" "$OUTROOT/tcc-0.9.27" 2>/dev/null
{
  echo "============ musl-crt-diag v21 WERROR-AB (real amd64) ============"
  grep -E "DIAG-IT|DIAG-CFG" "$WORK/rows.txt" 2>/dev/null
  echo "READ: if (a)/(d) OK and (b) CRASH, the -Werror= error-formatter is the wall; strip-Werror fixes R4."
  echo "================================================================="
} | tee "$MANIFEST"
exit 0
