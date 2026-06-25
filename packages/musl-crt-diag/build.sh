#!/usr/bin/env bash
# musl-crt-diag v10 — CONFIRM the R3 tcc fix. Root cause (pinned by v6-v9 build-down): tcc-0.9.27 SIGSEGVs
# PARSING musl's src/internal/syscall.h `char __buf[static 15+3*sizeof(int)]` (C99 array-param `[static N]`).
# live-bootstrap fixes this IN TCC via ignore-static-inside-array.patch (tccgen.c post_type) — which R3
# originally MISSED. R3 now carries it (+ dont-skip-weak-symbols-ar, static-link). This probe builds against
# the PATCHED R3 tcc and confirms, in one cycle:
#   (1) pA2: `#include "syscall.h"` alone -> OK (was CRASH) — the direct fix check.
#   (2) breadth-24 sample -> OK count (was 13/24) — no other broad crashers?
#   (3) the 11 former crashers -> 11/11 OK.
#   (4) THE REAL R4 make (CC=tcc, AR="tcc -ar") -> does full musl libc.a build now, and if not, where?
# set +e, never aborts, exits 0 with greppable rows + OutputData.
set +e
set -u
TCC=/usr/bin/tcc
VERSION="${MINIMAL_ARG_VERSION:-1.1.24}"
SRC="musl-${VERSION}"; BUILDROOT="$(pwd)"
OUTROOT=/build/output/usr/share/musl-crt-diag; WORK=/build/diag
mkdir -p "$OUTROOT" "$WORK"; MANIFEST="$OUTROOT/MANIFEST.txt"
emit(){ echo "$1"; echo "$1" >> "$WORK/rows.txt"; }
emit "DIAG-INFO musl-crt-diag v10 CONFIRM-FIX — $("$TCC" -version 2>&1 | head -1)"
tar -xf "${SRC}.tar.gz" 2>/dev/null; cd "${SRC}" || { emit FATAL; exit 0; }
for p in makefile madvise_preserve_errno avoid_sys_clone disable_ctype_headers skip-pic-crt drop-dynamic-crt amd64-va-list; do
  patch -Np1 -i "${BUILDROOT}/${p}.patch" >/dev/null 2>&1
done
rm src/ctype/iswalpha.c src/ctype/iswalnum.c src/ctype/iswctype.c src/ctype/towctrans.c 2>/dev/null
rm include/iconv.h src/locale/iconv.c src/locale/iconv_close.c 2>/dev/null; rm -rf src/complex 2>/dev/null
CC=tcc ./configure --host=x86_64 --disable-shared --prefix=/usr --libdir=/usr/lib --includedir=/usr/include >/dev/null 2>&1
make obj/include/bits/alltypes.h obj/include/bits/syscall.h >/dev/null 2>&1
FULL="-std=c99 -nostdinc -ffreestanding -fexcess-precision=standard -frounding-math -Wa,--noexecstack -D_XOPEN_SOURCE=700 -I./arch/x86_64 -I./arch/generic -Iobj/src/internal -I./src/include -I./src/internal -Iobj/include -I./include -Os -pipe -fomit-frame-pointer -fno-unwind-tables -fno-asynchronous-unwind-tables -ffunction-sections -fdata-sections -DSYSCALL_NO_TLS -fno-stack-protector"
cls(){ rc=$1; if [ "$rc" = 0 ]; then echo OK; elif [ "$rc" -gt 128 ] 2>/dev/null; then echo "CRASH(rc=$rc)"; else echo "err(rc=$rc)"; fi; }
try(){ "$TCC" $FULL -c -o "$WORK/t.o" "$1" >"$WORK/t.err" 2>&1; cls $?; }

# (1) the direct fix check: syscall.h alone.
printf '#include "syscall.h"\n' > src/internal/_pA2.c
emit "DIAG-CONFIRM pA2(syscall.h alone) -> $(try src/internal/_pA2.c)   [expect OK; was CRASH]"

# (2) breadth-24 + (3) the 11 former crashers
SAMPLE="src/aio/aio.c src/string/memcpy.c src/string/strlen.c src/string/strcmp.c src/stdlib/atoi.c src/stdlib/qsort.c src/stdio/fputs.c src/stdio/vfprintf.c src/stdio/snprintf.c src/malloc/malloc.c src/math/sqrt.c src/math/pow.c src/thread/pthread_mutex_lock.c src/time/gmtime.c src/ctype/isalpha.c src/errno/strerror.c src/env/getenv.c src/unistd/read.c src/signal/raise.c src/locale/setlocale.c src/regex/regcomp.c src/network/inet_pton.c src/prng/rand.c src/dirent/opendir.c"
ok=0; crash=0; badf=""
for f in $SAMPLE; do [ -f "$f" ] || continue; "$TCC" $FULL -c -o "$WORK/s.o" "$f" >/dev/null 2>&1; rc=$?
  if [ "$rc" = 0 ]; then ok=$((ok+1)); else crash=$((crash+1)); badf="$badf $(basename $f)($rc)"; fi; done
emit "DIAG-CONFIRM breadth-24 OK=$ok CRASH=$crash  still:$badf   [expect OK=24]"

# (4) THE REAL R4 make — does full musl libc.a build now?
emit "DIAG-INFO ===== (4) real R4 make ====="
make CROSS_COMPILE= AR="tcc -ar" RANLIB=true CFLAGS="-DSYSCALL_NO_TLS" >"$WORK/make.log" 2>&1; MRC=$?
NOBJ=$(find . -name '*.o' 2>/dev/null | wc -l)
emit "DIAG-MAKE rc=$MRC  objects=$NOBJ  libc.a=$( [ -f lib/libc.a ] && echo PRESENT:$(wc -c <lib/libc.a)B || echo ABSENT )"
if [ "$MRC" != 0 ]; then
  emit "DIAG-MAKE FAILED — last 8 log lines:"; tail -8 "$WORK/make.log" | while IFS= read -r l; do emit "DIAG-M| $l"; done
  # the file that failed (first non-zero compile in the log)
  emit "DIAG-MAKE first error context:"; grep -aE "error|Error|\.c$|signal|Segmentation" "$WORK/make.log" | head -6 | while IFS= read -r l; do emit "DIAG-M> $l"; done
else
  emit "DIAG-MAKE SUCCESS — full musl libc.a built with the patched R3 tcc. R4 is GREEN."
fi

cp "$WORK/rows.txt" "$OUTROOT/rows.txt.log" 2>/dev/null
cp "$WORK/make.log" "$OUTROOT/make.log" 2>/dev/null
cp "$TCC" "$OUTROOT/tcc-0.9.27" 2>/dev/null
[ -f lib/libc.a ] && cp lib/libc.a "$OUTROOT/libc.a" 2>/dev/null
{
  echo "============ musl-crt-diag v10 CONFIRM-FIX ============"
  grep -E "DIAG-CONFIRM|DIAG-MAKE|DIAG-M>" "$WORK/rows.txt" 2>/dev/null
  echo "READ: pA2 OK + breadth 24/24 => the [static] tcc fix landed. DIAG-MAKE SUCCESS => R4 builds;"
  echo "      else DIAG-M> shows the NEXT amd64 wall (a deeper construct), now on the patched tcc."
  echo "======================================================"
} | tee "$MANIFEST"
exit 0
