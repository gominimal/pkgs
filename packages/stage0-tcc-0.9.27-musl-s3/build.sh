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
emit "S3-INFO musl-relink — TM1(s1)=$("$TM1" -version 2>&1 | head -1)  musl libc.a=$(ls -la /usr/lib/libc.a 2>/dev/null | awk '{print $5}')B  stdio.h=$(test -f /usr/include/stdio.h && echo yes || echo NO)  libtcc1=$(ls -la $LT 2>/dev/null | awk '{print $5}')B"

cd /build/tm
tar --no-same-owner -xzf "$BUILDROOT/tccsrc.tar.gz" 2>/tmp/te || emit "S3-FAIL extract: $(head -1 /tmp/te)"
cd tccsrc || { emit "S3-FAIL no tccsrc (deterministic extract failure — NOT the lottery; fix the source, not a re-enqueue)"; cp /build/tm/rows.txt "$LOGOUT/rows.log"; echo fail | tee "$MAN"; exit 1; }
: > config.h

# copy s1's libtcc1.a through (tcc-musl2 bakes /usr/lib/tcc/libtcc1.a — same x86_64 archive)
cp "$LT" "$LIBOUT/libtcc1.a"

# TM1 (mes-linked, flaky on huge compile units) rebuilds tcc against MUSL -> tcc-musl2 (musl-linked).
# PIECEWISE, same as s1 (2026-08-04): the SIGSEGV scales with compile-unit size, and ONE_SOURCE=1
# was the one giant unit — s1 crossed this exact wall by compiling the ten units separately
# (retrospective 2026-06-30 called for this port; the 08-04 cold chain measured s3 crashing 3/3
# on the ONE_SOURCE compile right after a piecewise s1 sailed through).
TM2=/build/tcc-musl2
DEFS=(
  -D TCC_TARGET_X86_64=1
  -D ONE_SOURCE=0   # tcc.h:293 defaults ONE_SOURCE=1 when undefined; must be =0 explicitly for a
                    # real multi-file build (else libtcc.c/tcc.c #include the whole program and
                    # ST_FUNC=static breaks the link). Upstream Makefile:177 mandates this. (s1:36-41)
  -D 'CONFIG_TCCDIR="/usr/lib/tcc"'
  -D 'CONFIG_TCC_CRTPREFIX="/usr/lib"'
  -D 'CONFIG_TCC_LIBPATHS="/usr/lib:/usr/lib/tcc"'
  -D 'CONFIG_TCC_SYSINCLUDEPATHS="/usr/include"'
  -D 'TCC_LIBGCC="/usr/lib/tcc/libtcc1.a"'
  -D CONFIG_TCC_STATIC=1
  -D CONFIG_USE_LIBGCC=1
  -D 'TCC_VERSION="0.9.27musl2"'
)
UNITS="libtcc tccpp tccgen tccelf tccrun x86_64-gen x86_64-link i386-asm tccasm tcc"
built=0; bc=0; failunit=""
# Lottery is deterministic within a sandbox, so a big in-task loop can't escape a bad-layout task —
# keep it tiny; a re-enqueue (fresh sandbox = fresh layout) is the real retry.
for i in $(seq 1 9); do
  # Layout perturbation: with ASLR off, the child's initial stack position is a function of
  # envp+argv byte counts. Growing this var between tries gives each try a DIFFERENT layout —
  # the in-sandbox loop becomes a real re-roll instead of 3 identical draws (measured 2026-08-04:
  # outcome is fixed per layout; sandbox A failed 3/3, sandbox B passed 1/3, same box+sources).
  STACK_PAD="$(printf 'x%.0s' $(seq 1 $((i*17))))"; export STACK_PAD
  rm -f "$TM2"; for u in $UNITS; do rm -f "$u.o"; done; : > /tmp/be
  ok=1
  for u in $UNITS; do
    "$TM1" -w -c "${DEFS[@]}" -I . -I /usr/include -o "$u.o" "$u.c" 2>>/tmp/be
    bc=$?
    { [ "$bc" = 0 ] && [ -f "$u.o" ]; } || { ok=0; failunit="$u"; break; }
  done
  [ "$ok" = 1 ] || continue
  objs=""; for u in $UNITS; do objs="$objs $u.o"; done
  # $objs MUST word-split; TM1 is musl-configured so -static links musl crt + libc from /usr/lib
  "$TM1" -w -static -o "$TM2" $objs 2>>/tmp/be
  bc=$?
  { [ "$bc" = 0 ] && [ -x "$TM2" ]; } && { built=1; break; }   # require a CLEAN exit, not a crash's partial +x
done
emit "S3-BUILD tcc-musl2 built=$built piecewise (try $i/9 last-rc=$bc failunit=${failunit:-none} be-bytes=$(wc -c </tmp/be | tr -d ' '))"
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
    emit "S3-BUILD-ERR SIGSEGV rc=139 in tcc-musl (a compiled ELF; no Scheme interpreter or GC arena in this process) unit=${failunit:-link} — deterministic WITHIN this sandbox (all in-recipe tries share one layout); a NEW sandbox re-rolls it (measured 2026-08-04: s1 failed 3/3 then passed 1/3 in the next sandbox), so RE-ENQUEUE is the correct retry: $(tail -4 /tmp/be 2>/dev/null | tr '\n' '|')"
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
for i in 1 2 3 4 5; do
  rm -f h; "$TM2" -static -o h hello.c >/tmp/le 2>&1; lc=$?
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
