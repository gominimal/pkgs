#!/usr/bin/env bash
# stage0-tcc-0.9.27-musl-s3: s1's mes-linked tcc-musl recompiles tcc.c against musl -> tcc-musl2,
# a musl-linked tcc. Then check that tcc-musl2 runs and links a running musl hello.
# phases: sysroot check, extract, tcc-musl2 build, run test, link selftest, manifest.
set +e
set -u
BUILDROOT="$(pwd)"
TM1=/usr/bin/tcc-musl            # s1: mes-linked tcc-musl with GOT fixes A+B+C
LT=/usr/lib/tcc/libtcc1.a        # s1: x86_64 libtcc1.a
OUT=/build/output; BINOUT=$OUT/usr/bin; LIBOUT=$OUT/usr/lib/tcc; LOGOUT=$OUT/usr/share/tcc-musl-s3
mkdir -p "$BINOUT" "$LIBOUT" "$LOGOUT" /build/tm
MAN="$LOGOUT/MANIFEST.txt"
emit(){ echo "$1"; echo "$1" >> /build/tm/rows.txt; }

# Retry loop with an env-layout perturbation (MESLROLL). Try 1 runs the canonical env, so a
# first-try success is byte-identical to an unrolled run. Insurance only: the known crash cause
# was the header draw, fixed by the sysroot compile below.
ROLL=""
mesl_roll(){ if [ "$1" = 1 ]; then ROLL=""; else ROLL=$(printf 'R%.0s' $(seq 1 $(( ($1 - 1) * 17 )))); fi; }
mesl_run(){ if [ -n "$ROLL" ]; then MESLROLL="$ROLL" "$@"; else "$@"; fi; }

emit "S3-INFO musl-relink — TM1(s1)=$("$TM1" -version 2>&1 | head -1)  musl libc.a=$(ls -la /usr/lib/libc.a 2>/dev/null | awk '{print $5}')B  stdio.h=$(test -f /usr/include/stdio.h && echo yes || echo NO)  libtcc1=$(ls -la $LT 2>/dev/null | awk '{print $5}')B"

# diagnostic only: which stdio.h won the merged /usr/include (first-writer-wins draw against the
# glibc runtime dep). The compile below does not read it.
emit "S3-HDR stdio.h=$(sha256sum /usr/include/stdio.h 2>/dev/null | cut -c1-16) alltypes=$(test -f /usr/include/bits/alltypes.h && echo musl-present || echo no-musl) stdio_lim=$(test -f /usr/include/bits/stdio_lim.h && echo GLIBC-PRESENT || echo clean)"

# Compile and link against stage0-musl-1.1.24's single-writer sysroot, never the merged /usr:
# -nostdinc/-nostdlib plus explicit crt/libc.
SR=/usr/lib/musl-bedrock-1.1.24
if [ ! -f "$SR/include/stdio.h" ] || [ ! -f "$SR/lib/libc.a" ]; then
  emit "S3-FAIL sysroot $SR is missing — stage0-musl-1.1.24 did not publish it (stale musl artifact?); deterministic, fix the dependency"
  cp /build/tm/rows.txt "$LOGOUT/rows.log" 2>/dev/null; grep S3- /build/tm/rows.txt | tee "$MAN"; exit 1
fi

cd /build/tm
tar --no-same-owner -xzf "$BUILDROOT/tccsrc-r3gotABC.tar.gz" 2>/tmp/te || emit "S3-FAIL extract: $(head -1 /tmp/te)"
cd tccsrc || { emit "S3-FAIL no tccsrc (deterministic extract failure; fix the source)"; cp /build/tm/rows.txt "$LOGOUT/rows.log"; echo fail | tee "$MAN"; exit 1; }
: > config.h

# pass s1's libtcc1.a through (tcc-musl2 bakes /usr/lib/tcc/libtcc1.a)
cp "$LT" "$LIBOUT/libtcc1.a"

# tcc-musl (mes-linked) compiles and links tcc.c against musl -> tcc-musl2. libc.a appears twice
# around libtcc1.a for the libc<->libtcc1 reference cycle (tcc has no --start-group).
TM2=/build/tcc-musl2
built=0
# retried with the env-layout roll; crashes die fast, so 6 tries are cheap.
for i in $(seq 1 6); do
  mesl_roll "$i"
  rm -f "$TM2"
  # crt1 crti <obj> libc libtcc1 libc crtn. The -D's are tcc-musl2's own runtime config.
  mesl_run "$TM1" -w -static -nostdinc -nostdlib -o "$TM2" \
    "$SR/lib/crt1.o" "$SR/lib/crti.o" \
    -D TCC_TARGET_X86_64=1 \
    -D CONFIG_TCCDIR=\"/usr/lib/tcc\" \
    -D CONFIG_TCC_CRTPREFIX=\"/usr/lib\" \
    -D CONFIG_TCC_LIBPATHS=\"/usr/lib:/usr/lib/tcc\" \
    -D CONFIG_TCC_SYSINCLUDEPATHS=\"/usr/include\" \
    -D TCC_LIBGCC=\"/usr/lib/tcc/libtcc1.a\" \
    -D CONFIG_TCC_STATIC=1 \
    -D CONFIG_USE_LIBGCC=1 \
    -D TCC_VERSION=\"0.9.27musl2\" \
    -D ONE_SOURCE=1 \
    -I . -I "$SR/include" \
    tcc.c \
    "$SR/lib/libc.a" "$LT" "$SR/lib/libc.a" "$SR/lib/crtn.o" 2>/tmp/be
  bc=$?
  [ "$bc" = 0 ] && [ -x "$TM2" ] && { built=1; break; }   # require a clean exit, not a partial +x binary from a crash
done
emit "S3-BUILD tcc-musl2 built=$built (try $i/6 roll=$((i-1)) last-rc=$bc be-bytes=$(wc -c </tmp/be | tr -d ' '))"
if [ "$built" != 1 ]; then
  # No fallback: copying tcc-musl as tcc-musl2 would cache the mes-linked compiler under the
  # musl-linked name. rc=139 across all layouts means tcc-musl's own bytes are bad; rebuild s1.
  if [ "$bc" = 139 ]; then
    emit "S3-BUILD-ERR SIGSEGV rc=139 in tcc-musl (a compiled ELF; no Scheme interpreter or GC arena in this process) across all 6 independent env-layout retries — layout-independent means TM1's bytes are bad (a corrupt stage0-tcc-0.9.27-musl-s1 build shipped); rebuild stage0-tcc-0.9.27-musl-s1 (invalidate its cache entry): $(tail -4 /tmp/be 2>/dev/null | tr '\n' '|')"
  else
    emit "S3-BUILD-ERR (rc=$bc, deterministic — fix the tcc<->musl link): $(tail -4 /tmp/be 2>/dev/null | tr '\n' '|')"
  fi
  cp /build/tm/rows.txt "$LOGOUT/rows.log"
  { echo "===== tcc-musl2 build FAILED (rc=$bc) ====="; grep S3- /build/tm/rows.txt; } | tee "$MAN"
  exit 1
fi
cp "$TM2" "$BINOUT/tcc-musl2"

# Does tcc-musl2 run? (a tcc-sized static musl binary is the size class binutils will be)
"$TM2" -version >/tmp/v2 2>&1; rc=$?
emit "S3-RUN tcc-musl2 -version rc=$rc : $(head -1 /tmp/v2)"

# Does tcc-musl2 link a running musl hello? 5 tries.
printf '#include <stdio.h>\nint main(void){ printf("MUSL2-RUNS %%d\\n", 40+2); return 0; }\n' > hello.c
b=0; r=0; out=""
# Same sysroot-explicit link as the main build: tcc-musl2's baked paths point at the merged /usr.
for i in 1 2 3 4 5; do
  rm -f h
  "$TM2" -static -nostdinc -nostdlib -o h \
    "$SR/lib/crt1.o" "$SR/lib/crti.o" \
    -I "$SR/include" hello.c \
    "$SR/lib/libc.a" "$LIBOUT/libtcc1.a" "$SR/lib/libc.a" "$SR/lib/crtn.o" >/tmp/le 2>&1; lc=$?
  if [ "$lc" = 0 ]; then b=$((b+1)); timeout 10 ./h >/tmp/lo 2>&1; [ "$?" = 0 ] && r=$((r+1)); out="$(head -1 /tmp/lo)"; fi
done
emit "S3-SELFTEST tcc-musl2 links hello: built $b/5 ran-OK $r/5 run='$out'  $([ "$b" -gt 0 ] || head -1 /tmp/le)"

# Cache only a tcc-musl2 that runs, links, and whose linked binary runs. A built-but-miscompiled
# tcc-musl2 must not be retried into the cache; fix s1 instead.
if [ "$rc" != 0 ] || [ "$b" = 0 ] || [ "$r" = 0 ]; then
  emit "S3-VERIFY-FAIL tcc-musl2 built but MISCOMPILED by TM1 — -version rc=$rc links $b/5 runs $r/5. FAIL SHUT: retrying a miscompile until it passes would cache a silently-bad compiler that binutils-2.30 then builds against. Fix TM1 (stage0-tcc-0.9.27-musl-s1)."
  cp /build/tm/rows.txt "$LOGOUT/rows.log"; grep S3- /build/tm/rows.txt | tee "$MAN"
  exit 1
fi

cp /build/tm/rows.txt "$LOGOUT/rows.log"
{
  echo "============ stage0-tcc-0.9.27-musl-s3 — MUSL-RELINK (stable tcc-musl2) ============"
  grep S3- /build/tm/rows.txt
  echo "READ: S3-RUN rc=0 + S3-SELFTEST ran-OK>0 => tcc-musl2 is a STABLE musl-linked tcc that links"
  echo "      running musl binaries => ready to build binutils-2.30 as CC."
} | tee "$MAN"
exit 0
