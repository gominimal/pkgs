#!/usr/bin/env bash
# musl-crt-diag v6 — BREADTH assessment: the va_list fix cleared the crt; musl now crashes on aio.c.
# Strategic question: is tcc-0.9.27's amd64 codegen a few broad-fixable bugs, or pervasive (per-file
# whack-a-mole -> fix tcc + re-seal R3)? Compile a representative sample of musl src files (full flags)
# + count OK/CRASH, and -vv on aio.c for the specific construct. set +e, exit 0.
set +e
set -u
TCC=/usr/bin/tcc
VERSION="${MINIMAL_ARG_VERSION:-1.1.24}"
SRC="musl-${VERSION}"; BUILDROOT="$(pwd)"
OUTROOT=/build/output/usr/share/musl-crt-diag; WORK=/build/diag
mkdir -p "$OUTROOT" "$WORK"; MANIFEST="$OUTROOT/MANIFEST.txt"
emit(){ echo "$1"; echo "$1" >> "$WORK/rows.txt"; }
emit "DIAG-INFO musl-crt-diag v6 BREADTH — $("$TCC" -version 2>&1 | head -1)"
tar -xf "${SRC}.tar.gz" 2>/dev/null; cd "${SRC}" || { emit FATAL; exit 0; }
for p in makefile madvise_preserve_errno avoid_sys_clone disable_ctype_headers skip-pic-crt drop-dynamic-crt amd64-va-list; do
  patch -Np1 -i "${BUILDROOT}/${p}.patch" >/dev/null 2>&1
done
rm src/ctype/iswalpha.c src/ctype/iswalnum.c src/ctype/iswctype.c src/ctype/towctrans.c 2>/dev/null
rm include/iconv.h src/locale/iconv.c src/locale/iconv_close.c 2>/dev/null; rm -rf src/complex 2>/dev/null
CC=tcc ./configure --host=x86_64 --disable-shared --prefix=/usr --libdir=/usr/lib --includedir=/usr/include >/dev/null 2>&1
make obj/include/bits/alltypes.h obj/include/bits/syscall.h >/dev/null 2>&1
FULL="-std=c99 -nostdinc -ffreestanding -fexcess-precision=standard -frounding-math -Wa,--noexecstack -D_XOPEN_SOURCE=700 -I./arch/x86_64 -I./arch/generic -Iobj/src/internal -I./src/include -I./src/internal -Iobj/include -I./include -Os -pipe -fomit-frame-pointer -fno-unwind-tables -fno-asynchronous-unwind-tables -ffunction-sections -fdata-sections -DSYSCALL_NO_TLS -fno-stack-protector"

# (a) -vv on aio.c — the specific construct/header at the crash
emit "DIAG-INFO ===== (a) -vv aio.c ====="
"$TCC" -vv $FULL -c -o "$WORK/aio.o" src/aio/aio.c >"$WORK/aio.vv" 2>&1
emit "DIAG-AIO rc=$? last >>> $(grep -aE '^-> | -> ' "$WORK/aio.vv" 2>/dev/null | tail -5 | tr '\n' '|')"

# (b) BREADTH: compile a broad sample across subsystems; count OK vs CRASH (=139)
emit "DIAG-INFO ===== (b) breadth sample ====="
SAMPLE="src/aio/aio.c src/string/memcpy.c src/string/strlen.c src/string/strcmp.c src/stdlib/atoi.c src/stdlib/qsort.c src/stdio/fputs.c src/stdio/vfprintf.c src/stdio/snprintf.c src/malloc/malloc.c src/math/sqrt.c src/math/pow.c src/thread/pthread_mutex_lock.c src/time/gmtime.c src/ctype/isalpha.c src/errno/strerror.c src/env/getenv.c src/unistd/read.c src/signal/raise.c src/locale/setlocale.c src/regex/regcomp.c src/network/inet_pton.c src/prng/rand.c src/dirent/opendir.c"
ok=0; crash=0; other=0; crashed_files=""
for f in $SAMPLE; do
  [ -f "$f" ] || continue
  "$TCC" $FULL -c -o "$WORK/s.o" "$f" >"$WORK/s.err" 2>&1; rc=$?
  if [ "$rc" = "0" ]; then ok=$((ok+1));
  elif [ "$rc" = "139" ] || [ "$rc" -gt 128 ] 2>/dev/null; then crash=$((crash+1)); crashed_files="$crashed_files $(basename $f)";
  else other=$((other+1)); fi
done
emit "DIAG-BREADTH sample=$(echo $SAMPLE|wc -w) OK=$ok CRASH=$crash OTHER(clean-err)=$other"
emit "DIAG-BREADTH crashed: $crashed_files"

cp "$WORK/rows.txt" "$OUTROOT/rows.txt.log" 2>/dev/null; cp "$WORK/aio.vv" "$OUTROOT/aio.vv.log" 2>/dev/null
cp "$TCC" "$OUTROOT/tcc-0.9.27" 2>/dev/null
{
  echo "============ musl-crt-diag v6 BREADTH ============"
  grep -E "DIAG-AIO|DIAG-BREADTH" "$WORK/rows.txt" 2>/dev/null
  echo "INTERPRET: CRASH≈0 of sample => narrow (aio.c-specific, patch it). CRASH high => pervasive"
  echo "  tcc-0.9.27 amd64 codegen rot => fix tcc + re-seal R3 (the durable move, foreshadows R6)."
  echo "================================================="
} | tee "$MANIFEST"
exit 0
