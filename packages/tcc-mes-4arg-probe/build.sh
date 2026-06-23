#!/usr/bin/env bash
# tcc-mes-4arg-probe harness — see build.ncl for the full rationale.
#
# STAGE-A (always): INSTRUMENT x86_64-gen.c (12 asserts -> write(2,"GFnnnn\n",7)+_exit(NN)) via
#   /usr/bin/simple-patch BEFORE the mescc tcc.c->tcc.s step; build tcc-mes (R2's no-growth-arena
#   path, MES_ARENA==MES_MAX_ARENA=50M); gate on `tcc-mes -version`; populate include/arch/; then
#   compile the 4-arg crashers (execve.c first = minimal repro, + fcntl.c/_read.c/wait4.c/
#   snprintf.c) and the 3-arg OK contrast (access.c). The GFnnnn stderr marker + exit code PIN
#   which x86_64-gen.c assert fires on the >=4-arg path.
# STAGE-B (only if a fix Local was shipped, i.e. /build/fix.before exists): RESET x86_64-gen.c to
#   the pristine snapshot, simple-patch the candidate fix instead, rebuild tcc-mes, recompile
#   {execve,fcntl,_read,wait4,snprintf}.c and report PASS/CRASH per file.
#
# Greppable markers:
#   PROBE-RESULT <case> <OUTCOME> <secs>s rc=<rc> [marker=GFnnnn] [bytes=<n>]   (one per compile)
#   PROBE-ERRTAIL <case> >>> <last stderr lines>                               (non-OK triage)
#   PROBE-INFO  ...                                                            (progress / phases)
#   PROBE-TABLE ...                                                            (final summary rows)
# Harness ALWAYS exits 0.
set +e
set -u

# ── constant env (MUST match the production R2 tcc.kaem so STAGE-A reflects the real build) ──
export MES_PREFIX=/usr
export GUILE_LOAD_PATH=/usr/share/mes/mes/module:/usr/share/mes/module:/usr/share/nyacc/module
# Arena: MES_ARENA == MES_MAX_ARENA (NO GROWTH) is MANDATORY — the now-reliable R2 path. Growth
# (ARENA<MAX_ARENA) arms gc_up_arena's overflowing realloc (the now-solved mes-m2 instability).
export MES_STACK=15000000
export MES_ARENA=50000000
export MES_MAX_ARENA=50000000

MES=/usr/bin/mes-m2
MESCC=/usr/bin/mescc.scm
INCDIR=/usr/include/mes
MES_ARCH=x86_64
PREFIX=/usr
TCC_PKG=tcc-0.9.26-1147-gee75a10c
MES_PKG=mes-0.27.1
BINDIR=/build/output/usr/bin
LIBDIR=/build/output/usr/lib/mes
TCC=$BINDIR/tcc-mes

STAGEA_TIMEOUT=600        # bound the ~250s mescc tcc.c->tcc.s long pole
PERUNIT_TIMEOUT=120       # bound each -c compile (a crash/timeout can't eat the whole build)

XGEN=/build/$TCC_PKG/x86_64-gen.c
PRISTINE=/build/x86_64-gen.c.pristine

OUTROOT=/build/output/usr/share/tcc-mes-4arg-probe
mkdir -p "$OUTROOT"
MATRIX="$OUTROOT/matrix.txt"
WORK=/build/probe-logs
OBJDIR=/build/probe-obj
mkdir -p "$WORK" "$OBJDIR" "$BINDIR" "$LIBDIR"

# results accumulated for the final table (plain strings — no associative arrays, for max
# bash-bootstrap compatibility; one "name=outcome" token per crasher, space-separated)
PINNED_ASSERT="UNKNOWN"
A_TABLE=""
B_TABLE=""
STAGEB_RAN="no"

# ── the 12 instrumentation patches, IN APPLY ORDER. The three assert(0) MUST come first (same
#    before-file, first-match walks 1092->1313->2256). Each entry: "before-file after-file label".
INSTR=(
  "assert0.before assert0-a.after  assert0@1092"
  "assert0.before assert0-b.after  assert0@1313"
  "assert0.before assert0-c.after  assert0@2256"
  "gf-1318.before gf-1318.after     mode==sse@1318"
  "gf-1334.before gf-1334.after     mode==integer@1334"
  "gf-1355.before gf-1355.after     vtop/tmp@1355"
  "gf-1382.before gf-1382.after     mode==memory@1382"
  "gf-1409.before gf-1409.after     gen_reg<=REGN@1409"
  "gf-1410.before gf-1410.after     sse_reg<=8@1410"
  "gf-1428.before gf-1428.after     reg_count==1@1428"
  "gf-1450.before gf-1450.after     gen_reg==0@1450"
  "gf-1451.before gf-1451.after     sse_reg==0@1451"
)

# ── classify one tcc-mes -c compile into a bucket using rc + stderr signature + .o presence ──
classify() {
  # $1=rc  $2=stderr-file  $3=expected-.o (may be empty)
  local rc="$1" errf="$2" obj="${3:-}"
  if [ "$rc" = "0" ]; then
    if [ -n "$obj" ] && [ ! -s "$obj" ]; then echo "OK-NOOBJ"; return; fi
    echo "OK"; return
  fi
  # OUR instrumentation: a pinned assert prints GFnnnn then _exit(NN).
  if grep -qE 'GF[0-9]{4}' "$errf" 2>/dev/null; then
    echo "GF-ASSERT($(grep -oE 'GF[0-9]{4}' "$errf" | head -1))"; return
  fi
  # mes-libc's UNinstrumented assert path (a bare assert OUTSIDE our 12 sites) NULL-writes.
  if grep -qiE 'assert fail' "$errf" 2>/dev/null; then echo "ASSERTFAIL-UNINSTR/SIGSEGV"; return; fi
  case "$rc" in
    139) echo "SIGSEGV(11)"; return ;;
    134) echo "SIGABRT(6)"; return ;;
    124) echo "TIMEOUT"; return ;;
  esac
  if grep -qiE 'signal number = 11|abnormal termination' "$errf" 2>/dev/null; then echo "SIGSEGV(11)"; return; fi
  echo "OTHER($rc)"
}

# ── compile one source file with tcc-mes (-c), bounded, tolerant; emit a PROBE-RESULT row. ──
# Sets globals LAST_OUTCOME + LAST_MARKER. CWD must be the MES_PKG root.
compile_unit() {
  # $1=case-label  $2=source.c (relative to CWD)  $3=output.o  [$4=note]
  local label="$1" src="$2" obj="$3" note="${4:-}"
  local safe="${label//\//_}"
  local errf="$WORK/${safe}.err"
  rm -f "$obj" "$errf"
  local bytes=0; [ -f "$src" ] && bytes=$(wc -c < "$src" 2>/dev/null || echo 0)
  local t0=$SECONDS
  timeout "$PERUNIT_TIMEOUT" "$TCC" -c -D HAVE_CONFIG_H=1 -I include -I "include/linux/$MES_ARCH" \
    -o "$obj" "$src" >"$WORK/${safe}.out" 2>"$errf"
  local rc=$?
  local secs=$((SECONDS - t0))
  LAST_OUTCOME=$(classify "$rc" "$errf" "$obj")
  LAST_MARKER=$(grep -oE 'GF[0-9]{4}' "$errf" 2>/dev/null | head -1)
  echo "PROBE-RESULT $label $LAST_OUTCOME ${secs}s rc=$rc marker=${LAST_MARKER:-none} bytes=$bytes $note"
  case "$LAST_OUTCOME" in
    OK) : ;;
    *) echo "PROBE-ERRTAIL $label >>> $(tail -3 "$errf" 2>/dev/null | tr '\n' '|')" ;;
  esac
}

# ── build tcc-mes from the CURRENT /build/$TCC_PKG/x86_64-gen.c (already patched by caller). ──
# Returns 0 on a runnable tcc-mes, non-zero (with a PROBE-FATAL row) otherwise.
build_tcc_mes() {
  local phase="$1"   # "A" or "B" — for log/marker disambiguation
  cd "/build/$TCC_PKG" || { echo "PROBE-FATAL[$phase] cannot cd into tcc tree"; return 1; }
  : > config.h
  local MESCC_ARGS=(
    -S
    -o tcc.s
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
    tcc.c
  )
  echo "PROBE-INFO[$phase] mescc tcc.c -> tcc.s (no-growth arena, ~250s long pole) ..."
  local ta0=$SECONDS
  timeout "$STAGEA_TIMEOUT" "$MES" --no-auto-compile -e main "$MESCC" -- "${MESCC_ARGS[@]}" \
    >"$WORK/$phase-compile.out" 2>"$WORK/$phase-compile.err"
  local rc_compile=$?
  echo "PROBE-INFO[$phase] mescc compile rc=$rc_compile $((SECONDS-ta0))s ($(wc -l < tcc.s 2>/dev/null || echo 0) lines tcc.s)"
  if [ "$rc_compile" != "0" ] || [ ! -s tcc.s ]; then
    echo "PROBE-FATAL[$phase] mescc tcc.c->tcc.s FAILED (rc=$rc_compile) >>> $(tail -4 "$WORK/$phase-compile.err" 2>/dev/null | tr '\n' '|')"
    return 1
  fi
  echo "PROBE-INFO[$phase] mescc-link tcc.s -> tcc-mes ..."
  timeout "$STAGEA_TIMEOUT" "$MES" --no-auto-compile -e main "$MESCC" -- \
    --base-address 0x08048000 -o tcc-mes -L "$LIBDIR" tcc.s -l c+tcc \
    >"$WORK/$phase-link.out" 2>"$WORK/$phase-link.err"
  local rc_link=$?
  if [ "$rc_link" != "0" ] || [ ! -s tcc-mes ]; then
    echo "PROBE-FATAL[$phase] mescc link FAILED (rc=$rc_link) >>> $(tail -4 "$WORK/$phase-link.err" 2>/dev/null | tr '\n' '|')"
    return 1
  fi
  cp tcc-mes "$BINDIR/" && chmod 755 "$TCC"
  "$TCC" -version >"$WORK/$phase-version.out" 2>&1
  local rc_ver=$?
  TCC_VERSION_LINE=$(head -1 "$WORK/$phase-version.out" 2>/dev/null)
  echo "PROBE-INFO[$phase] tcc-mes -version rc=$rc_ver: $TCC_VERSION_LINE"
  if [ "$rc_ver" != "0" ]; then
    echo "PROBE-FATAL[$phase] tcc-mes -version FAILED (rc=$rc_ver) — built compiler is broken on a <4-arg path too."
    return 1
  fi
  return 0
}

# ── set up include/arch/ in the mes tree (must exist before any libc compile) ──
setup_mes_arch() {
  cd "/build/$MES_PKG" || { echo "PROBE-FATAL cannot cd into mes tree"; return 1; }
  : > include/mes/config.h
  mkdir -p include/arch
  cp "include/linux/$MES_ARCH/kernel-stat.h" include/arch/kernel-stat.h
  cp "include/linux/$MES_ARCH/signal.h"      include/arch/signal.h
  cp "include/linux/$MES_ARCH/syscall.h"     include/arch/syscall.h
  return 0
}

# crasher set (all emit a >=4-arg call) + the OK 3-arg contrast. execve.c = minimal repro.
CRASHERS=(
  "execve   lib/linux/execve.c"       # _sys_call3 (4-arg) — minimal deterministic repro
  "fcntl    lib/linux/fcntl.c"        # _sys_call3 (4-arg)
  "_read    lib/linux/_read.c"        # _sys_call3 (4-arg)
  "wait4    lib/linux/wait4.c"        # _sys_call4 (5-arg)
  "snprintf lib/stdio/snprintf.c"     # varargs / >=4-arg
)
CONTRAST="lib/linux/access.c"         # _sys_call2 (3-arg) — MUST stay OK

# ════════════════════════════════════════════════════════════════════════════════════════════
# STEP 0 — snapshot the PRISTINE x86_64-gen.c (for an optional STAGE-B fix that must NOT carry
#          the instrumentation). Then apply the 12 instrumentation patches.
# ════════════════════════════════════════════════════════════════════════════════════════════
echo "PROBE-INFO STEP0: snapshot pristine x86_64-gen.c + instrument 12 asserts"
echo "PROBE-INFO mes-m2: $($MES --version 2>&1 | head -1 || true)"

if [ ! -f "$XGEN" ]; then
  { echo "STEP0 FAILED: $XGEN missing (tcc Source did not extract?)"; } | tee "$MATRIX"
  exit 0
fi
cp "$XGEN" "$PRISTINE"

if ! command -v simple-patch >/dev/null 2>&1; then
  { echo "STEP0 FAILED: /usr/bin/simple-patch not found (stage0-mescc-full missing)"; } | tee "$MATRIX"
  exit 0
fi

INSTR_OK=1
for spec in "${INSTR[@]}"; do
  set -- $spec
  bf="/build/$1"; af="/build/$2"; lbl="$3"
  if simple-patch "$XGEN" "$bf" "$af"; then
    echo "PROBE-INFO instrumented $lbl"
  else
    echo "PROBE-FATAL instrument FAILED for $lbl (before-pattern not found in $XGEN)"
    INSTR_OK=0
    break
  fi
done
if [ "$INSTR_OK" != "1" ]; then
  { echo "STAGE-A FAILED: a simple-patch before-pattern did not match (byte drift vs the pinned tcc tarball)."; } | tee "$MATRIX"
  exit 0
fi
# sanity: all 12 GF markers must now be present in the instrumented source
GF_PRESENT=$(grep -oE 'GF[0-9]{4}' "$XGEN" | sort -u | tr '\n' ' ')
echo "PROBE-INFO instrumented markers present in source: $GF_PRESENT"

# ════════════════════════════════════════════════════════════════════════════════════════════
# STAGE-A — build instrumented tcc-mes and PIN the firing assert
# ════════════════════════════════════════════════════════════════════════════════════════════
echo "PROBE-INFO STAGE-A begin: build instrumented tcc-mes"
TCC_VERSION_LINE="(not built)"
if ! build_tcc_mes A; then
  { echo "STAGE-A FAILED before pin — see PROBE-FATAL[A] rows above."; echo "mes-m2 arena: $MES_ARENA/$MES_MAX_ARENA"; } | tee "$MATRIX"
  exit 0
fi

if ! setup_mes_arch; then
  { echo "STAGE-A FAILED: could not set up include/arch/."; } | tee "$MATRIX"
  exit 0
fi
echo "PROBE-INFO STAGE-A include/arch/ populated; compiling crashers + contrast"

# the OK 3-arg contrast first (proves the harness/headers are sane: must compile OK)
compile_unit "A-contrast-access(3arg)" "$CONTRAST" "$OBJDIR/access.o" "(_sys_call2 3-arg; MUST be OK)"
CONTRAST_OUTCOME="$LAST_OUTCOME"

# the crashers — execve.c first (minimal repro). Capture each marker.
for spec in "${CRASHERS[@]}"; do
  set -- $spec
  nm="$1"; src="$2"
  compile_unit "A-crash-$nm" "$src" "$OBJDIR/${nm}.o" "(>=4-arg call)"
  A_TABLE="$A_TABLE $nm=$LAST_OUTCOME"
  if [ "$nm" = "execve" ] && [ -n "${LAST_MARKER:-}" ]; then
    PINNED_ASSERT="$LAST_MARKER"
  fi
done
# fall back to fcntl's marker if execve somehow produced none
if [ "$PINNED_ASSERT" = "UNKNOWN" ]; then
  for nm in fcntl _read wait4 snprintf; do
    m=$(grep -oE 'GF[0-9]{4}' "$WORK/A-crash-${nm}.err" 2>/dev/null | head -1)
    if [ -n "$m" ]; then PINNED_ASSERT="$m"; break; fi
  done
fi
echo "PROBE-INFO STAGE-A PINNED_ASSERT=$PINNED_ASSERT"

# ════════════════════════════════════════════════════════════════════════════════════════════
# STAGE-B (optional) — only if a candidate-fix Local pair was shipped (/build/fix.before).
#   Reset to pristine, apply the fix, rebuild, recompile the crashers, report PASS/CRASH.
# ════════════════════════════════════════════════════════════════════════════════════════════
if [ -f /build/fix.before ] && [ -f /build/fix.after ]; then
  STAGEB_RAN="yes"
  echo "PROBE-INFO STAGE-B begin: candidate-fix test (reset pristine -> fix -> rebuild)"
  cp "$PRISTINE" "$XGEN"
  if simple-patch "$XGEN" /build/fix.before /build/fix.after; then
    echo "PROBE-INFO STAGE-B fix patch applied"
    if build_tcc_mes B && setup_mes_arch; then
      for spec in "${CRASHERS[@]}"; do
        set -- $spec
        nm="$1"; src="$2"
        compile_unit "B-fix-$nm" "$src" "$OBJDIR/${nm}_fix.o" "(post-fix)"
        if [ "$LAST_OUTCOME" = "OK" ]; then B_TABLE="$B_TABLE $nm=PASS"; else B_TABLE="$B_TABLE $nm=CRASH:$LAST_OUTCOME"; fi
      done
    else
      echo "PROBE-FATAL[B] STAGE-B rebuild failed — fix did not produce a runnable tcc-mes"
      for spec in "${CRASHERS[@]}"; do set -- $spec; B_TABLE="$B_TABLE $1=BUILD-FAILED"; done
    fi
  else
    echo "PROBE-FATAL[B] fix before-pattern did not match pristine x86_64-gen.c"
    for spec in "${CRASHERS[@]}"; do set -- $spec; B_TABLE="$B_TABLE $1=FIX-NOMATCH"; done
  fi
else
  echo "PROBE-INFO STAGE-B skipped (no /build/fix.before shipped — pin-only run)"
fi

# ════════════════════════════════════════════════════════════════════════════════════════════
# FINAL RESULT MATRIX — to stdout AND the OutputData artifact
# ════════════════════════════════════════════════════════════════════════════════════════════
{
  echo "================ tcc-mes-4arg-probe RESULT MATRIX ================"
  echo "host: $(uname -a 2>/dev/null)"
  echo "tcc-mes: $TCC_VERSION_LINE"
  echo "mes-m2 arena: MES_ARENA=$MES_ARENA MES_MAX_ARENA=$MES_MAX_ARENA (no-growth)"
  echo "instrumented sites: 1092,1313,2256 (assert(0)) + 1318,1334,1355,1382,1409,1410,1428,1450,1451"
  echo "------------------------------------------------------------------"
  printf 'PROBE-TABLE %-26s %s\n' "PINNED_ASSERT (execve.c)" "$PINNED_ASSERT"
  printf 'PROBE-TABLE %-26s %s\n' "contrast access.c (3-arg)" "$CONTRAST_OUTCOME"
  echo "-- STAGE-A per-crasher (instrumented; GFnnnn = firing x86_64-gen.c line) --"
  for spec in "${CRASHERS[@]}"; do set -- $spec; v=$(printf '%s\n' $A_TABLE | grep "^$1=" | head -1); printf 'PROBE-TABLE %-26s %s\n' "A $1" "${v#*=}"; done
  if [ "$STAGEB_RAN" = "yes" ]; then
    echo "-- STAGE-B per-crasher (candidate fix; PASS = compiled clean) --"
    for spec in "${CRASHERS[@]}"; do set -- $spec; v=$(printf '%s\n' $B_TABLE | grep "^$1=" | head -1); printf 'PROBE-TABLE %-26s %s\n' "B $1" "${v#*=}"; done
  else
    echo "-- STAGE-B: not run (pin-only; ship fix.before/fix.after to test a dodge) --"
  fi
  echo "------------------------------------------------------------------"
  echo "MARKER -> x86_64-gen.c SITE:"
  echo "  GF1092=classify_x86_64_inner default assert(0)   GF1313=gfunc_call VT_LDOUBLE assert(0)"
  echo "  GF2256=gen_cvt_ftoi default assert(0)            GF1334=mode==integer  GF1409=gen_reg<=REGN"
  echo "  GF1410=sse_reg<=8  GF1428=reg_count==1  GF1450=gen_reg==0  GF1451=sse_reg==0"
  echo "  GF1318=mode==sse  GF1355=vtop/tmp type  GF1382=mode==memory"
  echo "------------------------------------------------------------------"
  echo "INTERPRETATION:"
  echo " * contrast access.c=OK + crashers GF-ASSERT  => harness reproduces the >=4-arg wall and"
  echo "   the instrumentation landed (the firing assert self-identifies)."
  echo " * GF1092  => classify_x86_64_inner read a GARBAGE type.t (vtop[-i] mis-addressed): the"
  echo "   counting/swap loop over the 4th value-stack slot is miscompiled by mescc. TOP prediction."
  echo " * GF1313  => the gfunc_call switch(vtop->type.t & VT_BTYPE) misrouted an INTEGER arg into"
  echo "   the VT_LDOUBLE arm (corrupted BTYPE reads as 10). Also a type-corruption verdict."
  echo " * GF1450/GF1451/GF1409/GF1410  => a gen_reg/sse_reg COUNTER was clobbered on the 4-arg"
  echo "   register dance (would CONTRADICT 'assert fail: 0' => nyacc-stringize theory was wrong)."
  echo " * a crasher SIGSEGVs with NO GFnnnn (ASSERTFAIL-UNINSTR/SIGSEGV) => the firing assert is"
  echo "   OUTSIDE the 12 instrumented sites (e.g. a tccgen.c get_reg/save_regs/load() assert) or a"
  echo "   wild store — extend instrumentation to those asserts in a follow-up."
  echo " * NEXT: ship a fix.before/fix.after Local that rewrites the pinned construct (e.g. hoist"
  echo "   vtop[-i] into a local SValue* for GF1092/GF1313, or reorder the integer-arg emission for"
  echo "   a counter pin) — STAGE-B then tests it in the SAME 2-build budget."
  echo "=================================================================="
} | tee "$MATRIX"

echo "PROBE-INFO matrix written to $MATRIX"
exit 0
