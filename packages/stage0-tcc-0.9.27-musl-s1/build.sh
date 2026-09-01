#!/usr/bin/env bash
# R4a STAGE 1 — build the GOT-fixed tcc-0.9.27 in a CLEAN MES env (R1+R2, no R4 → no header collision).
# tcc-0.9.26 compiles tcc.c vs mes headers + links vs mes crt (mes-linked, static, self-contained). BAKED
# prefixes are MUSL (/usr/lib, /usr/include) for stage 2. Output: static mes-linked tcc-musl + libtcc1.a.
set +e
set -u
BUILDROOT="$(pwd)"
TCC26=/usr/bin/tcc-0.9.26
OUT=/build/output; BINOUT=$OUT/usr/bin; LIBOUT=$OUT/usr/lib/tcc; LOGOUT=$OUT/usr/share/tcc-musl-s1
mkdir -p "$BINOUT" "$LIBOUT" "$LOGOUT" /build/tm
MAN="$LOGOUT/MANIFEST.txt"
emit(){ echo "$1"; echo "$1" >> /build/tm/rows.txt; }

# LAYOUT ROLL (probe wf_81e7d78f, coreutils-probe 2026-09-01): mes-linked ELF behavior is a
# DETERMINISTIC function of the env area (order AND byte length — arm B: every permutation
# seed gave a distinct output sha; arm C: ±1 env byte changed the sha). "Deterministic within
# a sandbox" therefore only holds while the env is fixed — so each retry below deliberately
# perturbs the child env layout, turning the in-recipe loop into INDEPENDENT draws instead of
# N replays of the same doomed layout. Try 1 always runs the canonical (unmodified) env, so a
# first-try success is byte-identical to the pre-roll recipe.
ROLL=""
mesl_roll(){ # $1 = try number; sets ROLL (empty on try 1 = canonical env)
  if [ "$1" = 1 ]; then ROLL=""; else ROLL=$(printf 'R%.0s' $(seq 1 $(( ($1 - 1) * 17 )))); fi
}
mesl_run(){ if [ -n "$ROLL" ]; then MESLROLL="$ROLL" "$@"; else "$@"; fi; }

emit "S1-INFO build GOT-fixed tcc-musl (mes-linked, musl-configured) in clean MES env — $($TCC26 -version 2>&1 | head -1)"
emit "S1-INFO mes crt: $(ls -la /usr/lib/mes/crt1.o 2>/dev/null | awk '{print $5}')B  mes libc.a: $(ls -la /usr/lib/mes/libc.a 2>/dev/null | awk '{print $5}')B  mes hdr stdlib.h: $(test -f /usr/include/stdlib.h && echo yes || echo NO)"

cd /build/tm
tar --no-same-owner -xzf "$BUILDROOT/tccsrc-r3got-s1.tar.gz" 2>/tmp/te; xrc=$?
[ "$xrc" = 0 ] || emit "S1-FAIL extract: $(head -1 /tmp/te)"
cd tccsrc || { emit "S1-FAIL no tccsrc dir"; cp /build/tm/rows.txt "$LOGOUT/rows.log"; echo fail | tee "$MAN"; cp "$TCC26" "$BINOUT/tcc-musl"; : > "$LIBOUT/libtcc1.a"; exit 0; }
: > config.h
emit "S1-INFO extracted $(ls | wc -l | tr -d ' ') files; GOT fix: $(grep -c 'R5 amd64 static-GOT fix' tccelf.c) (fill_got@$(grep -n 'fill_got(s1)' tccelf.c | head -1 | cut -d: -f1) tidy@$(grep -n 'tidy_section_headers(s1, sec_order)' tccelf.c | head -1 | cut -d: -f1))"

# libtcc1.a (x86_64) -> output (stage 2's TCC_LIBGCC=/usr/lib/tcc/libtcc1.a).
# Rolled retries here too: a crashed unit compile used to fall through to an EMPTY archive
# (the `: > libtcc1.a` backstop below), shipping a silent poison that only surfaced at s3.
for i in $(seq 1 4); do
  mesl_roll "$i"
  rm -f /tmp/lt.o /tmp/va.o
  mesl_run $TCC26 -c -D TCC_TARGET_X86_64=1 -o /tmp/lt.o lib/libtcc1.c 2>/tmp/l1
  mesl_run $TCC26 -c -D TCC_TARGET_X86_64=1 -o /tmp/va.o lib/va_list.c 2>/tmp/l2
  [ -f /tmp/lt.o ] && [ -f /tmp/va.o ] && break
done
$TCC26 -ar cr "$LIBOUT/libtcc1.a" /tmp/lt.o /tmp/va.o 2>/tmp/l3
emit "S1-LIBTCC1 libtcc1.a=$(ls -la $LIBOUT/libtcc1.a 2>/dev/null | awk '{print $5}')B"

# build tcc-musl PIECEWISE: tcc-0.9.26 compiles each tcc source as a SEPARATE small unit (NO ONE_SOURCE),
# then links them. The mes-libc SIGSEGV scales with compile-unit SIZE — ~10 small units crash far less
# often than the one giant ONE_SOURCE tcc.c (~5%/sandbox). (Frequency fix, NOT the root cause: the
# root cause is env-layout-dependent mes-libc behavior — see the LAYOUT ROLL note above. The rolled
# retries are the in-recipe escape hatch when a bad layout still bites.)
TM=/build/tcc-musl
# DEFS bake the MUSL config into the .o's (bash array so the -D "..." string literals survive intact);
# tcc-0.9.26 links the .o's with its OWN (mes) crt -> mes-linked but musl-configured tcc-musl (unchanged).
DEFS=(
  -D TCC_TARGET_X86_64=1
  -D ONE_SOURCE=0   # CRITICAL: tcc.h:293 defaults ONE_SOURCE=1 when undefined; must set =0 explicitly
                    # for a real multi-file build (else libtcc.c/tcc.c #include the whole program and
                    # ST_FUNC=static breaks the link). Upstream tcc Makefile:177 mandates this.
  -D 'CONFIG_TCCDIR="/usr/lib/tcc"'
  -D 'CONFIG_TCC_CRTPREFIX="/usr/lib"'
  -D 'CONFIG_TCC_ELFINTERP="/mes/loader"'
  -D 'CONFIG_TCC_LIBPATHS="/usr/lib:/usr/lib/tcc"'
  -D 'CONFIG_TCC_SYSINCLUDEPATHS="/usr/include"'
  -D 'TCC_LIBGCC="/usr/lib/tcc/libtcc1.a"'
  -D CONFIG_TCC_STATIC=1
  -D CONFIG_USE_LIBGCC=1
  -D 'TCC_VERSION="0.9.27PW2"'
)
INCS=(-I . -I /usr/include -I /usr/include/mes)
# x86_64 units: matches libtcc.c's ONE_SOURCE includes for TCC_TARGET_X86_64 + CONFIG_TCC_ASM, plus
# tcc.c (the CLI, which unconditionally #includes tcctools.c -> carries `-ar`). NO ONE_SOURCE => each
# is its own small compilation unit.
UNITS="libtcc tccpp tccgen tccelf tccrun x86_64-gen x86_64-link i386-asm tccasm tcc"
built=0; bc=0; failunit=""
for i in $(seq 1 6); do
  mesl_roll "$i"
  rm -f "$TM"; for u in $UNITS; do rm -f "$u.o"; done; : > /tmp/be
  ok=1
  for u in $UNITS; do
    mesl_run "$TCC26" -w -c "${DEFS[@]}" "${INCS[@]}" -o "$u.o" "$u.c" 2>>/tmp/be
    bc=$?
    { [ "$bc" = 0 ] && [ -f "$u.o" ]; } || { ok=0; failunit="$u"; break; }
  done
  [ "$ok" = 1 ] || continue
  objs=""; for u in $UNITS; do objs="$objs $u.o"; done
  # $objs MUST word-split into the .o args; tcc-0.9.26 supplies its own (mes) crt under -static
  mesl_run "$TCC26" -w -static -o "$TM" $objs 2>>/tmp/be
  bc=$?
  { [ "$bc" = 0 ] && [ -x "$TM" ]; } && { built=1; break; }
done
emit "S1-BUILD tcc-musl built=$built piecewise (try $i/6 roll=$((i-1)) last-rc=$bc failunit=${failunit:-none} be=$(wc -c </tmp/be | tr -d ' '))"
if [ "$built" = 1 ]; then
  cp "$TM" "$BINOUT/tcc-musl"
  emit "S1-OK tcc-musl: $("$TM" -version 2>&1 | head -1)"
else
  # NO fallback (it poisons the cache as fake success).
  #
  # 2026-07-21 CORRECTION -- this block used to emit a marker containing the literal tokens
  # "mes-m2" and "tcc.c->tcc.s" for ONE reason: categorize_stderr (orch-queue/src/lib.rs:471-482)
  # requires (SIGSEGV|rc=139) AND (mescc|mes-m2|tcc.c->tcc.s|dynamic-wind...) to return
  # MesccArenaLottery, which is_transient_retryable() then re-rolls. NEITHER TOKEN IS TRUE HERE:
  # the crashing process is $TCC26 = /usr/bin/tcc-0.9.26, a COMPILED ELF linked against mes-libc.
  # There is no mes-m2 interpreter and no Scheme GC arena in this process, and the failing unit is
  # whatever $failunit says (UNITS starts at libtcc), not tcc.c.
  #
  # The consequence was real: a DETERMINISTIC mes-libc SIGSEGV was classified transient, so the
  # builder auto-re-enqueued it and operators were told to "re-roll". It blocked packages/mrustc
  # twice on 2026-07-21 -- mrustc has no no_auto_retry flag, so it burned retries on a dependency
  # that had already set one. The `retry_count: 2` seen there was the DETERMINISM guard
  # (SAME_SIG_LIMIT, queue_mode.rs:219) firing, not budget exhaustion; the builder was right.
  #
  # The marker below is now TRUTHFUL, which means it no longer matches MesccArenaLottery and
  # correctly falls through to BuildScriptFailed (not retryable). That is the desired behaviour:
  # this is a real undiagnosed bug in mes-libc, not a draw to re-roll. Do NOT re-add the tokens to
  # buy retries -- fix the segfault. NOTE the tokens are SUBSTRING-matched, so you cannot even
  # write "NOT mes-m2" in an emitted string without re-triggering the classifier -- describe the
  # mechanism without naming it (this bit me while writing this very fix). (ASLR is separately disabled globally now, Dockerfile.prod:91
  # -> sandbox2 personality(ADDR_NO_RANDOMIZE), so the old "per-task ASLR" attribution is stale too.)
  if [ "$bc" = 139 ]; then
    emit "S1-BUILD-ERR mes-libc SIGSEGV rc=139 in tcc-0.9.26 (a compiled ELF linked against mes-libc; no Scheme interpreter and no GC arena are in this process) compiling unit=${failunit:-link} across ALL 6 INDEPENDENT env-layout draws — layout-independent means a REAL bug, not a draw; do not re-enqueue: $(tail -4 /tmp/be 2>/dev/null | tr '\n' '|')"
  else
    emit "S1-BUILD-ERR (non-lottery, rc=$bc unit=${failunit:-link}, deterministic — fix the recipe, not a re-enqueue): $(tail -4 /tmp/be 2>/dev/null | tr '\n' '|')"
  fi
fi
[ -f "$LIBOUT/libtcc1.a" ] || : > "$LIBOUT/libtcc1.a"

cp /build/tm/rows.txt "$LOGOUT/rows.log"
{
  echo "============ stage0-tcc-0.9.27-musl-s1 (GOT-fixed mes-linked tcc, clean MES env) ============"
  grep "S1-" /build/tm/rows.txt
  echo "READ: S1-OK + libtcc1.a>0 => stage-1 tcc-musl built; stage 2 (vs R4 musl) tests the GOT fix."
} | tee "$MAN"
# built=0 (lottery) -> exit non-zero: a CLEAN task failure carrying the rc=139 marker, so the queue
# categorizes it MesccArenaLottery and --retry-on-lottery re-enqueues (fresh sandbox). built=1 -> 0.
[ "$built" = 1 ] || exit 1
exit 0
