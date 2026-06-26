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

# (a) confirm crash + make the self-contained reducer
"$TCC" $FULL -c -o "$WORK/it.o" "$F" >"$WORK/it.err" 2>&1; emit "DIAG-IT __init_tls.c -> $(cls $?)"
"$TCC" -E $FULL "$F" > "$WORK/it.i" 2>/dev/null
"$TCC" $FULL -c -o "$WORK/ii.o" "$WORK/it.i" >/dev/null 2>&1; emit "DIAG-IT __init_tls.i (preprocessed) -> $(cls $?)   lines=$(wc -l <"$WORK/it.i")"

# (b) prefix-bisect __init_tls.i for the smallest crashing head -N
LO=1; HI=$(wc -l < "$WORK/it.i")
"$TCC" $FULL -c -o "$WORK/p.o" "$WORK/it.i" >/dev/null 2>&1
if [ "$?" -gt 128 ]; then
  while [ $LO -lt $HI ]; do
    MID=$(( (LO+HI)/2 ))
    head -n $MID "$WORK/it.i" > "$WORK/pre.c"
    "$TCC" $FULL -c -o "$WORK/p.o" "$WORK/pre.c" >/dev/null 2>&1; rc=$?
    if [ "$rc" -gt 128 ] 2>/dev/null; then HI=$MID; else LO=$((MID+1)); fi
  done
  emit "DIAG-IT prefix-bisect: smallest crashing head -N = $LO"
  emit "DIAG-IT context (lines $((LO-4))..$((LO+1))):"
  sed -n "$((LO-4)),$((LO+1))p" "$WORK/it.i" | while IFS= read -r l; do emit "DIAG-L| $l"; done
fi

# (c) which include alone crashes
emit "DIAG-INFO ===== include isolation ====="
for h in elf.h limits.h sys/mman.h string.h stddef.h pthread_impl.h libc.h atomic.h syscall.h; do
  printf '#include "%s"\nint x;\n' "$h" > "$WORK/h.c" 2>/dev/null
  printf '#include <%s>\nint x;\n' "$h" > "$WORK/h2.c" 2>/dev/null
  "$TCC" $FULL -c -o "$WORK/h.o" "$WORK/h.c" >/dev/null 2>&1; r1=$?
  "$TCC" $FULL -c -o "$WORK/h.o" "$WORK/h2.c" >/dev/null 2>&1; r2=$?
  [ "$r1" -gt 128 ] 2>/dev/null && emit "DIAG-INC \"$h\" -> CRASH"
  [ "$r2" -gt 128 ] 2>/dev/null && emit "DIAG-INC <$h> -> CRASH"
done

cp "$WORK/rows.txt" "$OUTROOT/rows.txt.log" 2>/dev/null
cp "$WORK/it.i" "$OUTROOT/init_tls.i.log" 2>/dev/null
cp "$TCC" "$OUTROOT/tcc-0.9.27" 2>/dev/null
{
  echo "============ musl-crt-diag v20 INITTLS-REDUCE ============"
  grep -E "DIAG-IT|DIAG-L\\||DIAG-INC" "$WORK/rows.txt" 2>/dev/null
  echo "READ: the prefix-bisect boundary line + context = the construct tcc miscompiles on real amd64."
  echo "========================================================="
} | tee "$MANIFEST"
exit 0
