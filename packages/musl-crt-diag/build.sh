#!/usr/bin/env bash
# musl-crt-diag v9 — BUILD-DOWN bisection on the REAL read.c. v6/v7/v8 narrowed by elimination but every
# hand-built minimal TU (syscall_arch.h swap, hidden multi-declarator, 7-arg call) COMPILES while the real
# files CRASH — so the trigger needs the real include environment, not a reconstruction. syscall.h has NO
# static inlines (just macros), so it's not "codegen'd unused static". v9 reduces the ACTUAL read.c
# (smallest crasher) step by step against the REAL headers to localize the crash to one of:
#   pE  tcc -E read.c            -> preprocessor/macro expansion?
#   pA2 #include "syscall.h"     -> parsing syscall.h alone?
#   pA1 #include <unistd.h>      -> parsing unistd.h alone?
#   pA  both includes, no fn     -> header interaction?
#   pB  includes + trivial body  -> the function signature (ssize_t/size_t)?
#   pC  real read.c              -> the syscall_cp(...) body? (control: must crash)
# Whatever is the FIRST to crash gets -vv + a head of its preprocessed form for the next cut. Pure
# diagnosis this cycle (no fix matrix until the construct is real). set +e, exit 0, OutputData.
set +e
set -u
TCC=/usr/bin/tcc
VERSION="${MINIMAL_ARG_VERSION:-1.1.24}"
SRC="musl-${VERSION}"; BUILDROOT="$(pwd)"
OUTROOT=/build/output/usr/share/musl-crt-diag; WORK=/build/diag
mkdir -p "$OUTROOT" "$WORK"; MANIFEST="$OUTROOT/MANIFEST.txt"
emit(){ echo "$1"; echo "$1" >> "$WORK/rows.txt"; }
emit "DIAG-INFO musl-crt-diag v9 BUILD-DOWN — $("$TCC" -version 2>&1 | head -1)"
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

# Build-down TUs live in src/internal so quote-includes resolve exactly as real musl files do.
DIR=src/internal
printf '#include <unistd.h>\n' > "$DIR/_pA1.c"
printf '#include "syscall.h"\n' > "$DIR/_pA2.c"
printf '#include <unistd.h>\n#include "syscall.h"\n' > "$DIR/_pA.c"
printf '#include <unistd.h>\n#include "syscall.h"\nssize_t read(int fd,void*buf,size_t count){(void)fd;(void)buf;(void)count;return 0;}\n' > "$DIR/_pB.c"

emit "DIAG-INFO ===== build-down on real read.c ====="
"$TCC" -E $FULL src/unistd/read.c > "$WORK/read.i" 2>"$WORK/read.E.err"; emit "DIAG-BD pE(-E preprocess) -> $(cls $?)  (read.i lines=$(wc -l < "$WORK/read.i" 2>/dev/null))"
emit "DIAG-BD pA1(unistd.h only)     -> $(try "$DIR/_pA1.c")"
emit "DIAG-BD pA2(syscall.h only)    -> $(try "$DIR/_pA2.c")"
emit "DIAG-BD pA(both, no fn)        -> $(try "$DIR/_pA.c")"
emit "DIAG-BD pB(incl+trivial body)  -> $(try "$DIR/_pB.c")"
emit "DIAG-BD pC(real read.c)        -> $(try src/unistd/read.c)"

# If preprocessing succeeded, the crash is reproducible from the self-contained .i — confirm + measure,
# so next cycle can bisect read.i mechanically (no headers).
if [ -s "$WORK/read.i" ]; then
  cp "$WORK/read.i" "$DIR/_read_i.c"
  emit "DIAG-BD pI(compile read.i)     -> $(try "$DIR/_read_i.c")   <- if CRASH, read.i is the self-contained reducer"
  emit "DIAG-INFO read.i tail (the actual read() after expansion):"
  tail -12 "$WORK/read.i" | while IFS= read -r ln; do emit "DIAG-I| $ln"; done
fi

# -vv on the first crashing minimal include TU, to see exactly where include-scan stops.
for t in _pA2 _pA1 _pA; do
  if [ "$(try "$DIR/$t.c")" != OK ]; then
    "$TCC" -vv $FULL -c -o "$WORK/x.o" "$DIR/$t.c" > "$WORK/$t.vv" 2>&1
    emit "DIAG-INFO -vv $t last includes: $(grep -aE '^->| -> ' "$WORK/$t.vv" | tail -4 | tr '\n' '|')"
    break
  fi
done

cp "$WORK/rows.txt" "$OUTROOT/rows.txt.log" 2>/dev/null
cp "$WORK/read.i" "$OUTROOT/read.i.log" 2>/dev/null
cp "$TCC" "$OUTROOT/tcc-0.9.27" 2>/dev/null
{
  echo "============ musl-crt-diag v9 BUILD-DOWN ============"
  grep -E "DIAG-BD|DIAG-I\\||DIAG-INFO -vv" "$WORK/rows.txt" 2>/dev/null
  echo "READ: first CRASH localizes it — pA2=syscall.h parse, pA1=unistd parse, pB=signature, pC=body."
  echo "      If pE OK and pI CRASH, read.i is a self-contained reducer for a mechanical line-bisect."
  echo "===================================================="
} | tee "$MANIFEST"
exit 0
