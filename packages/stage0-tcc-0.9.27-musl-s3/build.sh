#!/usr/bin/env bash
# R4a STAGE 3 — musl-relink: s1's mes-linked tcc-musl rebuilds tcc.c against MUSL -> tcc-musl2 (MUSL-linked,
# stable). Then test tcc-musl2 (a big musl binary): does it RUN, and does IT link a running musl hello?
set +e
set -u
BUILDROOT="$(pwd)"
TM1=/usr/bin/tcc-musl            # s1: mes-linked tcc-musl with fixes A+B+C
LT=/usr/lib/tcc/libtcc1.a        # s1: x86_64 libtcc1.a
OUT=/build/output; BINOUT=$OUT/usr/bin; LIBOUT=$OUT/usr/lib/tcc; LOGOUT=$OUT/usr/share/tcc-musl-s3
mkdir -p "$BINOUT" "$LIBOUT" "$LOGOUT" /build/tm
MAN="$LOGOUT/MANIFEST.txt"
emit(){ echo "$1"; echo "$1" >> /build/tm/rows.txt; }

# LAYOUT ROLL — cheap insurance only. The env-layout probe (wf_81e7d78f, coreutils-probe,
# 2026-09-01) ran 91 trials across permutation/length/arena sweeps and reproduced NOTHING
# (verdict MESL_ALL_ARMS_CLEAN; it hashed environments, not outputs, so it carries no output-
# determinism evidence either). The PROVEN cause of this rung's rc=139/be=0 was the rootfs
# header race — cured by the -nostdinc/-nostdlib sysroot compile below, not by these rolls.
# Each retry perturbs the child env layout anyway (uninit-memory reads of the env area remain
# plausible per the mes-m2 dossier, and a roll costs nothing on the success path): try 1 keeps
# the canonical env, so a first-try success is byte-identical to the pre-roll recipe.
ROLL=""
mesl_roll(){ if [ "$1" = 1 ]; then ROLL=""; else ROLL=$(printf 'R%.0s' $(seq 1 $(( ($1 - 1) * 17 )))); fi; }
mesl_run(){ if [ -n "$ROLL" ]; then MESLROLL="$ROLL" "$@"; else "$@"; fi; }

emit "S3-INFO musl-relink — TM1(s1)=$("$TM1" -version 2>&1 | head -1)  musl libc.a=$(ls -la /usr/lib/libc.a 2>/dev/null | awk '{print $5}')B  stdio.h=$(test -f /usr/include/stdio.h && echo yes || echo NO)  libtcc1=$(ls -la $LT 2>/dev/null | awk '{print $5}')B"

# WHICH stdio.h won the merged /usr/include? Diagnostic only (the compile below no longer cares):
# minimal's rootfs overlay is an unordered hash-set with first-writer-wins collisions, so the
# glibc runtime anchor races this rung's musl for /usr/include/** and /usr/lib/{*.a,crt*.o}.
# When glibc's stdio.h won, TM1 died in glibc's bits/*.h chain and the mes-libc error reporter
# SIGSEGV'd eating the diagnostic (rc=139, be=0) — the entire historical "s3 lottery" (2026-08-04
# core: rdi="In file ", stack in bits/stdio_lim.h). Read the draw here instead of inferring it.
emit "S3-HDR stdio.h=$(sha256sum /usr/include/stdio.h 2>/dev/null | cut -c1-16) alltypes=$(test -f /usr/include/bits/alltypes.h && echo musl-present || echo no-musl) stdio_lim=$(test -f /usr/include/bits/stdio_lim.h && echo GLIBC-PRESENT || echo clean)"

# DRAW IMMUNITY: compile+link against R4a's single-writer sysroot (uncontended paths published
# by stage0-musl-1.1.24 §E), never the merged /usr — the same cure R5's musl-cc wrapper uses
# with R4b's /usr/lib/musl-bedrock. -nostdinc/-nostdlib + explicit crt/libc below.
SR=/usr/lib/musl-bedrock-1.1.24
if [ ! -f "$SR/include/stdio.h" ] || [ ! -f "$SR/lib/libc.a" ]; then
  emit "S3-FAIL sysroot $SR is missing — stage0-musl-1.1.24 §E did not publish it (stale musl artifact?); deterministic, fix the dep, not a re-enqueue"
  cp /build/tm/rows.txt "$LOGOUT/rows.log" 2>/dev/null; grep S3- /build/tm/rows.txt | tee "$MAN"; exit 1
fi

cd /build/tm
tar --no-same-owner -xzf "$BUILDROOT/tccsrc-r3gotABC.tar.gz" 2>/tmp/te || emit "S3-FAIL extract: $(head -1 /tmp/te)"
cd tccsrc || { emit "S3-FAIL no tccsrc (deterministic extract failure — NOT the lottery; fix the source, not a re-enqueue)"; cp /build/tm/rows.txt "$LOGOUT/rows.log"; echo fail | tee "$MAN"; exit 1; }
: > config.h

# copy s1's libtcc1.a through (tcc-musl2 bakes /usr/lib/tcc/libtcc1.a — same x86_64 archive)
cp "$LT" "$LIBOUT/libtcc1.a"

# TM1 (mes-linked, flaky on the big tcc.c) compiles+LINKS tcc.c against MUSL -> tcc-musl2 (musl-linked).
# libc.a TWICE for the libc<->libtcc1 abort cycle. Retry the mes-libc lottery.
TM2=/build/tcc-musl2
built=0
# Rolled retries: the lottery is deterministic PER ENV LAYOUT (not per sandbox) — mesl_roll gives
# each try its own layout, so the loop escapes a bad draw in-recipe. --retry-on-lottery (fresh
# sandbox) and buildbot re-runs remain the outer fallback; 6 tries is cheap since crashes die fast.
for i in $(seq 1 6); do
  mesl_roll "$i"
  rm -f "$TM2"
  # -nostdinc/-nostdlib + explicit sysroot crt/libc (R5 musl-cc order: crt1 crti <obj> libc
  # libtcc1 libc crtn — libc twice around libtcc1 for the abort<->libc cycle). The -D's bake
  # TM2's OWN runtime config (unchanged); this invocation just no longer READS the drawn /usr.
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
  [ "$bc" = 0 ] && [ -x "$TM2" ] && { built=1; break; }   # require a CLEAN compile exit (bc=0), not a partial +x binary from a crash
done
emit "S3-BUILD tcc-musl2 built=$built (try $i/6 roll=$((i-1)) last-rc=$bc be-bytes=$(wc -c </tmp/be | tr -d ' '))"
if [ "$built" != 1 ]; then
  # NO cache-poisoning fallback (cp TM1 -> tcc-musl2 would ship s1's flaky mes-linked compiler as the
  # supposedly-stable musl tcc-musl2 — s1:58-59 warns against exactly this). Leave tcc-musl2 absent.
  # Key the marker on the CAPTURED compile exit $bc: 139 => the per-task ASLR lottery (matchable marker
  # -> MesccArenaLottery -> --retry-on-lottery re-rolls in a fresh sandbox); else a deterministic
  # tcc<->musl link/compile bug (BuildScriptFailed; a re-enqueue won't help — fix the recipe).
  if [ "$bc" = 139 ]; then
    # 2026-07-21 CORRECTION: this marker used to contain the literal tokens "mes-m2" and
    # "tcc.c->tcc.s" purely to match categorize_stderr (orch-queue/src/lib.rs:471-482) and buy an
    # auto-retry. Neither is true: TM1 is /usr/bin/tcc-musl, a COMPILED ELF -- no interpreter and
    # no GC arena in this process. It also fired only after ALL 30 in-recipe tries failed, which is
    # evidence of DETERMINISM, not of a draw. The tokens are SUBSTRING-matched, so even writing
    # "NOT mes-m2" re-triggers the classifier -- describe the mechanism without naming it.
    emit "S3-BUILD-ERR SIGSEGV rc=139 in tcc-musl (a compiled ELF; no Scheme interpreter or GC arena in this process) across ALL 6 INDEPENDENT env-layout draws — layout-independent means TM1's BYTES are bad (a corrupt s1 draw shipped); rebuild s1 (invalidate its cache entry), do not re-enqueue this stage: $(tail -4 /tmp/be 2>/dev/null | tr '\n' '|')"
  else
    emit "S3-BUILD-ERR (non-lottery, rc=$bc, deterministic — fix the tcc<->musl link, not a re-enqueue): $(tail -4 /tmp/be 2>/dev/null | tr '\n' '|')"
  fi
  cp /build/tm/rows.txt "$LOGOUT/rows.log"
  { echo "===== tcc-musl2 build FAILED (rc=$bc) ====="; grep S3- /build/tm/rows.txt; } | tee "$MAN"
  exit 1
fi
cp "$TM2" "$BINOUT/tcc-musl2"

# Does tcc-musl2 (a BIG musl binary) RUN? (the stress test — if a tcc-sized musl static binary runs, binutils will)
"$TM2" -version >/tmp/v2 2>&1; rc=$?
emit "S3-RUN tcc-musl2 -version rc=$rc : $(head -1 /tmp/v2)"

# Does tcc-musl2 (MUSL-linked, stable) link a RUNNING musl hello? (5x — should be reliable, no mes lottery)
printf '#include <stdio.h>\nint main(void){ printf("MUSL2-RUNS %%d\\n", 40+2); return 0; }\n' > hello.c
b=0; r=0; out=""
# Same sysroot-explicit link as the main build: TM2's BAKED paths point at the drawn /usr
# (correct for its sealed consumers, which wrap it — see R5's musl-cc), so the selftest must
# not read them either.
for i in 1 2 3 4 5; do
  rm -f h
  "$TM2" -static -nostdinc -nostdlib -o h \
    "$SR/lib/crt1.o" "$SR/lib/crti.o" \
    -I "$SR/include" hello.c \
    "$SR/lib/libc.a" "$LIBOUT/libtcc1.a" "$SR/lib/libc.a" "$SR/lib/crtn.o" >/tmp/le 2>&1; lc=$?
  if [ "$lc" = 0 ]; then b=$((b+1)); timeout 10 ./h >/tmp/lo 2>&1; [ "$?" = 0 ] && r=$((r+1)); out="$(head -1 /tmp/lo)"; fi
done
emit "S3-SELFTEST tcc-musl2 links hello: built $b/5 ran-OK $r/5 run='$out'  $([ "$b" -gt 0 ] || head -1 /tmp/le)"

# Gate caching on a tcc-musl2 that actually WORKS: runs (-version rc=0) AND links (b>0) AND the linked
# binary RUNS (r>0 — a links-but-non-running tcc-musl2 is still miscompiled). A built-but-miscompiled
# tcc-musl2 is a flaky-TM1 lottery outcome (s1's mes-linked compiler emitted garbage) — route it to
# --retry-on-lottery (matchable marker) for a fresh roll rather than caching a broken compiler that R5
# binutils would then build against.
if [ "$rc" != 0 ] || [ "$b" = 0 ] || [ "$r" = 0 ]; then
  emit "S3-VERIFY-FAIL tcc-musl2 built but MISCOMPILED by TM1 — -version rc=$rc links $b/5 runs $r/5. FAIL SHUT: re-rolling a miscompile until it passes is how a silently-bad compiler gets cached and signed, and R5 binutils then builds against it. Fix TM1 (s1), do not re-enqueue."
  cp /build/tm/rows.txt "$LOGOUT/rows.log"; grep S3- /build/tm/rows.txt | tee "$MAN"
  exit 1
fi

cp /build/tm/rows.txt "$LOGOUT/rows.log"
{
  echo "============ stage0-tcc-0.9.27-musl-s3 — MUSL-RELINK (stable tcc-musl2) ============"
  grep S3- /build/tm/rows.txt
  echo "READ: S3-RUN rc=0 + S3-SELFTEST ran-OK>0 => tcc-musl2 is a STABLE musl-linked tcc that links"
  echo "      running musl binaries => ready to build R5 binutils as CC (no mes-libc lottery)."
} | tee "$MAN"
exit 0
