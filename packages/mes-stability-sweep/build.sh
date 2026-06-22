#!/usr/bin/env bash
# mes-stability-sweep harness — see build.ncl for the full rationale.
#
# Sweeps mes-m2 arena/stack/ulimit/ASLR configs over the EXACT R2 mescc tcc.c->tcc.s compile,
# N=3 per config, NEVER aborting on a per-config crash (set +e). Emits SWEEP-* markers + a final
# RESULT MATRIX to BOTH stdout (debug-log bucket) and $OUTPUT_DIR/usr/share/.../matrix.txt, then
# exits 0 so the log/artifact are always retrievable.
#
# Greppable markers:
#   SWEEP-RESULT  <label> run<i> <OUTCOME> <secs>s rc=<rc> ulimitSs=<v> growthFired=<y/n>
#   SWEEP-DEBUG   <label> growthFired=<y/n>            (the MES_DEBUG=3 'up[' probe)
#   SWEEP-SKIP    <label> SKIPPED-OVERFLOW ...         (budget-guard rejected config)
#   SWEEP-MATRIX  ...                                   (the final per-config summary table rows)
set +e
set -u

# ── constant env (must MATCH the production R2 tcc.kaem so the sweep reflects the real compile) ──
export MES_PREFIX=/usr
export GUILE_LOAD_PATH=/usr/share/mes/mes/module:/usr/share/mes/module:/usr/share/nyacc/module

MES=/usr/bin/mes-m2
MESCC=/usr/bin/mescc.scm
INCDIR=/usr/include/mes
TCC_PKG=tcc-0.9.26-1147-gee75a10c
# These two paths are only baked as -D string literals; they need not exist for the -S compile.
LIBDIR=/build/output/usr/lib/mes
PREFIX=/usr

PERRUN_TIMEOUT=480        # seconds per single mescc compile (crash/timeout bounds the total)
N=2                       # repeats per config (ASLR/run-to-run variance); 2 keeps wall-time sane — each PASS run is multi-minute
# 32-bit budget guard: reject any config whose INITIAL arena malloc (ARENA*1.1 + STACK)*24 would
# approach 2^32 (=4.295e9). Threshold in CELLS = 3.8e9/24 ~= 158,000,000.
GUARD_CELLS=158000000

OUTROOT=/build/output/usr/share/mes-stability-sweep
mkdir -p "$OUTROOT"
MATRIX="$OUTROOT/matrix.txt"
WORK=/build/sweep-logs
mkdir -p "$WORK"

# ── reach the crash point: empty config.h (BOOTSTRAP defines arrive via -D, per tcc.kaem) ──
# (We deliberately SKIP the tcctools.c simple-patch: it relocates a runtime fopen() and does not
#  change the parse/codegen path that crashes. Noted as a faithfulness caveat in the report.)
: > "/build/$TCC_PKG/config.h"
cd "/build/$TCC_PKG" || { echo "SWEEP-FATAL cannot cd into tcc tree"; exit 0; }

# ── the mescc -D argv, byte-faithful to R2 tcc.kaem:134-155. The CONFIG_*/TCC_* string literals
#    MUST carry LITERAL double-quotes into mescc; the bash array preserves them. `inline=` is an
#    empty-value define (one element). Output -o and tcc.c are appended per run. ──
build_args() {
  ARGS=(
    -S
    -I "$INCDIR"
    -D BOOTSTRAP=1
    -D HAVE_LONG_LONG=1
    -I .
    -D TCC_TARGET_X86_64=1
    -D inline=
    -D "CONFIG_TCCDIR=\"$LIBDIR/tcc\""
    -D "CONFIG_SYSROOT=\"/\""
    -D "CONFIG_TCC_CRTPREFIX=\"$LIBDIR\""
    -D "CONFIG_TCC_ELFINTERP=\"/mes/loader\""
    -D "CONFIG_TCC_SYSINCLUDEPATHS=\"$PREFIX/include/mes\""
    -D "TCC_LIBGCC=\"$LIBDIR/libc.a\""
    -D CONFIG_TCC_LIBTCC1_MES=0
    -D CONFIG_TCCBOOT=1
    -D CONFIG_TCC_STATIC=1
    -D CONFIG_USE_LIBGCC=1
    -D "TCC_VERSION=\"0.9.26\""
    -D ONE_SOURCE=1
  )
}
build_args

# ── one-time: does setarch -R actually work in this sandbox? (personality(ADDR_NO_RANDOMIZE)
#    may be seccomp-blocked by the CS launcher — the ASLR-off rows then report SETARCH-BLOCKED) ──
ARCHM="$(uname -m)"
SETARCH_OK=0
if command -v setarch >/dev/null 2>&1; then
  if setarch "$ARCHM" -R /usr/bin/true >/dev/null 2>&1; then SETARCH_OK=1; fi
fi
echo "SWEEP-INFO setarch -R usable: $SETARCH_OK (arch=$ARCHM)"
echo "SWEEP-INFO mes-m2: $($MES --version 2>&1 | head -1 || true)"

# ── classify one run's exit into a bucket using rc + stderr signature ──
classify() {
  # $1=rc  $2=stderr-file  $3=out-.s-file
  local rc="$1" errf="$2" sf="$3"
  if [ "$rc" = "0" ]; then
    local lines=0
    [ -f "$sf" ] && lines=$(wc -l < "$sf" 2>/dev/null || echo 0)
    if [ "$lines" -gt 50000 ]; then echo "PASS"; else echo "PASS-SHORT(${lines}ln)"; fi
    return
  fi
  case "$rc" in
    139) echo "SIGSEGV(11)"; return ;;
    134) if grep -qiE 'STACK FULL' "$errf" 2>/dev/null; then echo "SIGABRT-STACKFULL";
         elif grep -qiE 'out of memory' "$errf" 2>/dev/null; then echo "SIGABRT-OOM";
         else echo "SIGABRT(6)"; fi; return ;;
    124) echo "TIMEOUT"; return ;;
  esac
  if grep -qiE 'parse failed|expr->register|not supported' "$errf" 2>/dev/null; then
    echo "PARSEFAIL"; return
  fi
  echo "OTHER($rc)"
}

# ── run one (config x repeat). ulimit + env are set INSIDE a subshell; rc/ss returned via files. ──
run_one() {
  # $1=label $2=arena $3=maxarena $4=stack $5=ulimit $6=aslr(on/off) $7=run-idx
  local label="$1" arena="$2" maxa="$3" stk="$4" ulim="$5" aslr="$6" idx="$7"
  local tag="${label}-r${idx}"
  local outs="$WORK/${tag}.s" errf="$WORK/${tag}.err" rcf="$WORK/${tag}.rc" ssf="$WORK/${tag}.ss"
  rm -f "$outs" "$errf" "$rcf" "$ssf"

  local wrap=()
  if [ "$aslr" = "off" ]; then
    if [ "$SETARCH_OK" = "1" ]; then wrap=(setarch "$ARCHM" -R)
    else echo "SWEEP-RESULT $label run$idx SETARCH-BLOCKED 0s rc=- ulimitSs=- growthFired=-"; return; fi
  fi

  local t0=$SECONDS
  (
    if [ "$ulim" = "unlimited" ]; then ulimit -s unlimited 2>/dev/null
    else ulimit -s "$ulim" 2>/dev/null; fi
    ulimit -Ss > "$ssf" 2>/dev/null || echo "?" > "$ssf"
    export MES_ARENA="$arena" MES_MAX_ARENA="$maxa" MES_STACK="$stk"
    "${wrap[@]}" timeout "$PERRUN_TIMEOUT" \
      "$MES" --no-auto-compile -e main "$MESCC" -- "${ARGS[@]}" -o "$outs" tcc.c \
      > "$WORK/${tag}.out" 2> "$errf"
    echo $? > "$rcf"
  )
  local secs=$((SECONDS - t0))
  local rc; rc=$(cat "$rcf" 2>/dev/null || echo "NORC")
  local ss; ss=$(cat "$ssf" 2>/dev/null || echo "?")
  local growth="n"; [ "$arena" != "$maxa" ] && growth="y"
  local outcome; outcome=$(classify "$rc" "$errf" "$outs")
  echo "SWEEP-RESULT $label run$idx $outcome ${secs}s rc=$rc ulimitSs=$ss growthFired=$growth"
  # one short stderr tail per non-PASS run, for at-a-glance triage in the log
  case "$outcome" in
    PASS) : ;;
    *) echo "SWEEP-ERRTAIL $label run$idx >>> $(tail -3 "$errf" 2>/dev/null | tr '\n' '|')" ;;
  esac
  # remember last outcome per config for the summary table
  echo "$outcome" >> "$WORK/${label}.outcomes"
}

# ── THE MATRIX:  label | MES_ARENA | MES_MAX_ARENA | MES_STACK | ulimit_s | aslr ──
# Required rows: baseline 30M no-growth; ulimit -s rows; no-growth bigger-arena rows; a growth
# row; an ASLR-off (setarch -R) row. Plus growth-isolators. Each config run N=3 times.
CONFIGS=(
  # ── BASELINE: the canonical upstream / case-A success (ulimit default 8192, ASLR on) ──
  "baseline-30M|30000000|30000000|15000000|8192|on"

  # ── NO-GROWTH SIZE LADDER (ARENA==MAX_ARENA => gc_up_arena never fires), stack 15M, all
  #    safely under the ~162M 32-bit-overflow ceiling; 120M is the deliberate near-ceiling probe ──
  "nogrow-50M|50000000|50000000|15000000|8192|on"
  "nogrow-80M|80000000|80000000|15000000|8192|on"
  "nogrow-120M|120000000|120000000|15000000|8192|on"

  # ── OS C-STACK axis (hold 30M/30M; the lever upstream never sets). Predict NO effect because
  #    eval_apply is a goto-trampoline; an EFFECT here would itself be the informative result ──
  "ulimit-64M|30000000|30000000|15000000|65536|on"
  "ulimit-unlim|30000000|30000000|15000000|unlimited|on"

  # ── GROWTH rows (ARENA<MAX_ARENA => arms gc_up_arena realloc + pointer-relocating memcpy) ──
  #   small-growth isolator: first doubling 20M->40M does NOT overflow 32-bit ((40M+4M)*24=1.06e9)
  #   so a crash here proves the realloc-rebase bug INDEPENDENT of overflow; a pass blames overflow.
  "grow-iso-20to40|20000000|40000000|15000000|8192|on"
  #   case-C repro: 100M->300M, stack 40M (the exact failing prod config). Initial malloc safe
  #   (3.6e9<3.8e9); first doubling 100M->200M overflows ((200M+20M)*24=5.28e9>2^32) -> expect SIGSEGV.
  "grow-caseC|100000000|300000000|40000000|8192|on"

  # ── ASLR-OFF (setarch -R) control on the two most diagnostic configs. If outcomes become
  #    deterministic with -R but flaky without, the instability is address/layout-dependent ──
  "aslroff-30M|30000000|30000000|15000000|8192|off"
  "aslroff-caseC|100000000|300000000|40000000|8192|off"
)

echo "SWEEP-INFO begin matrix: ${#CONFIGS[@]} configs x N=$N repeats, per-run timeout=${PERRUN_TIMEOUT}s"
for cfg in "${CONFIGS[@]}"; do
  IFS='|' read -r label arena maxa stk ulim aslr <<< "$cfg"
  # budget guard on the INITIAL malloc (does NOT guard the growth-doubling overflow — that is
  # intentionally observed in the grow-* rows): reject if (arena*1.1 + stack) >= GUARD_CELLS.
  cells=$(( arena * 11 / 10 + stk ))
  if [ "$cells" -ge "$GUARD_CELLS" ]; then
    echo "SWEEP-SKIP $label SKIPPED-OVERFLOW initCells=$cells >= guard=$GUARD_CELLS"
    echo "SKIPPED-OVERFLOW" > "$WORK/${label}.outcomes"
    continue
  fi
  echo "SWEEP-INFO config $label arena=$arena max=$maxa stack=$stk ulimit=$ulim aslr=$aslr initCells=$cells"
  for i in $(seq 1 "$N"); do
    run_one "$label" "$arena" "$maxa" "$stk" "$ulim" "$aslr" "$i"
  done
done

# ── MES_DEBUG probe: confirm/refute that gc_up_arena fired before the crash. g_debug>2 prints
#    'up[' on every arena growth. Run ONCE each on a no-growth and a growth config (verbose). ──
for cfg in "baseline-30M|30000000|30000000|15000000" "grow-caseC|100000000|300000000|40000000"; do
  IFS='|' read -r label arena maxa stk <<< "$cfg"
  derr="$WORK/${label}.debug.err"
  (
    ulimit -s 8192 2>/dev/null
    export MES_ARENA="$arena" MES_MAX_ARENA="$maxa" MES_STACK="$stk" MES_DEBUG=3
    timeout "$PERRUN_TIMEOUT" \
      "$MES" --no-auto-compile -e main "$MESCC" -- "${ARGS[@]}" -o "$WORK/${label}.debug.s" tcc.c \
      > "$WORK/${label}.debug.out" 2> "$derr"
  )
  fired="n"; grep -q 'up\[' "$derr" 2>/dev/null && fired="y"
  echo "SWEEP-DEBUG $label growthFired=$fired"
done

# ── FINAL RESULT MATRIX (to stdout AND the artifact) ─────────────────────────────────────────
{
  echo "================ mes-stability-sweep RESULT MATRIX ================"
  echo "host: $(uname -a 2>/dev/null)"
  echo "setarch -R usable: $SETARCH_OK   N=$N   per-run timeout=${PERRUN_TIMEOUT}s"
  echo "mes-m2: $($MES --version 2>&1 | head -1 || true)"
  echo "GUARD_CELLS(initial 32-bit budget)=$GUARD_CELLS  cell=24B  ceiling~162.7M cells"
  echo "------------------------------------------------------------------"
  printf '%-18s %-12s %-12s %-10s %-9s %-5s | %s\n' \
    LABEL ARENA MAX_ARENA STACK ULIMIT ASLR "RUN OUTCOMES (x$N)"
  for cfg in "${CONFIGS[@]}"; do
    IFS='|' read -r label arena maxa stk ulim aslr <<< "$cfg"
    oc="-"; [ -f "$WORK/${label}.outcomes" ] && oc=$(tr '\n' ' ' < "$WORK/${label}.outcomes")
    printf 'SWEEP-MATRIX %-18s %-12s %-12s %-10s %-9s %-5s | %s\n' \
      "$label" "$arena" "$maxa" "$stk" "$ulim" "$aslr" "$oc"
  done
  echo "------------------------------------------------------------------"
  echo "INTERPRETATION:"
  echo " * baseline/nogrow all PASS 3/3, growth rows SIGSEGV => fix = pin MES_ARENA==MES_MAX_ARENA"
  echo "   (disable growth); pick smallest nogrow size that is PASS 3/3 as the robust R2 config."
  echo " * grow-iso-20to40 SIGSEGV (no 32-bit overflow on its first doubling) => realloc-rebase bug,"
  echo "   not just overflow; growth path is structurally broken => must disable growth regardless."
  echo " * ulimit-* differs from baseline => C-stack overflow (unexpected); else C-stack REFUTED."
  echo " * aslroff-* deterministic while ASLR-on flaky => layout-dependent UB (deeper mes-m2 fix)."
  echo " * ANY nogrow size flaky across its 3 runs => no env knob is robust => deeper mes-m2/M2-Planet"
  echo "   fix needed (run a SYSTEM_LIBC gcc-built mes under valgrind/ASan to localize the wild write)."
  echo "=================================================================="
} | tee "$MATRIX"

echo "SWEEP-INFO matrix written to $MATRIX"
exit 0
