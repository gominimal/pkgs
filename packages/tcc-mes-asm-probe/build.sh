#!/usr/bin/env bash
# tcc-mes-asm-probe — ONE-build GROUND-TRUTH forensics + FIX#2 test for the amd64 mes-tcc
# >=4-arg-call SIGSEGV (mescc miscompiles tcc-mes's gfunc_call; the 4th int arg's type.t is
# corrupted -> x86_64-gen.c:1318 assert(mode==x86_64_mode_sse) fires at COMPILE TIME).
#
# (A) CAPTURE: build the CANONICAL tcc-mes via R2's no-growth-arena mescc path and capture, as
#     retrievable OutputData: the mescc-EMITTED asm (tcc.s, M1/stage0 syntax) sliced for gfunc_call
#     and classify_x86_64_arg (+inner/merge/gfunc_prolog), the FULL tcc.s gzipped, and the linked
#     tcc-mes binary (static ELF, for local `objdump -d`). Also run the 4 crashers to PIN the
#     canonical CRASH baseline.
# (B) FIX#2: reset x86_64-gen.c to pristine, apply the FIELD-BY-FIELD SValue swap (replace the two
#     whole-struct swaps in gfunc_call's run loop with per-field copies — splits the 42-byte mescc
#     chunked mem->mem struct-copy into scalar stores + a clean 16-byte CValue union copy), rebuild
#     tcc-mes, capture its gfunc_call slice + diff vs canonical, and RECOMPILE
#     {execve,fcntl,wait4,snprintf}.c -> PASS/CRASH per file. The matrix is the verdict on whether
#     the struct-copy (not the vtop[-i] addressing the FAILED fix#1 rewrote) is the bug.
#
# Greppable markers (stdout AND OutputData):
#   ASM-INFO    ...                                              progress / phases
#   ASM-RESULT  <phase> <fn> lines=<n> bytes=<n>                 one per sliced function
#   PROBE-RESULT <case> <OUTCOME> <secs>s rc=<rc> [marker=..]    one per -c compile
#   PROBE-ERRTAIL <case> >>> <stderr tail>                       non-OK triage
#   PROBE-TABLE  ...                                             final matrix rows
#   FATAL       ...                                              a sub-step failed (STILL exits 0)
# Harness is a diagnostic probe, not a trust rung: set +e, never abort, ALWAYS exit 0.
set +e
set -u

# ── constant env: MUST match production R2 tcc.kaem so the captured asm == the real build ──
export MES_PREFIX=/usr
export GUILE_LOAD_PATH=/usr/share/mes/mes/module:/usr/share/mes/module:/usr/share/nyacc/module
# Arena: MES_ARENA == MES_MAX_ARENA (NO GROWTH) is MANDATORY — the now-reliable R2 path.
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

STAGE_TIMEOUT=600         # bound each ~250s mescc tcc.c->tcc.s long pole (run TWICE)
LINK_TIMEOUT=300
PERUNIT_TIMEOUT=120       # bound each -c compile (a crash/timeout can't eat the build)

XGEN=/build/$TCC_PKG/x86_64-gen.c
PRISTINE=/build/x86_64-gen.c.pristine

OUTROOT=/build/output/usr/share/tcc-mes-asm-probe
WORK=/build/probe-logs
OBJDIR=/build/probe-obj
mkdir -p "$OUTROOT" "$WORK" "$OBJDIR" "$BINDIR" "$LIBDIR"
MANIFEST="$OUTROOT/MANIFEST.txt"

# functions to slice out of tcc.s. gfunc_call (SysV #else def, source ~1195-1473) carries the
# assert@1318 AND the field-by-field swap; classify_x86_64_arg is what it calls at every
# vtop[-i].type site (it reads SValue.type at offset 0 — the corrupted field).
SLICE_FNS=(gfunc_call classify_x86_64_arg classify_x86_64_inner classify_x86_64_merge gfunc_prolog)

# the 4 crashers (each emits a >=4-arg call). execve.c = minimal deterministic repro.
CRASHERS=(
  "execve   lib/linux/execve.c"     # _sys_call3 (4-arg) — minimal repro
  "fcntl    lib/linux/fcntl.c"      # _sys_call3 (4-arg)
  "wait4    lib/linux/wait4.c"      # _sys_call4 (5-arg)
  "snprintf lib/stdio/snprintf.c"   # varargs / >=4-arg
)
CONTRAST="lib/linux/access.c"       # _sys_call2 (3-arg) — MUST stay OK (sanity)

A_TABLE=""; B_TABLE=""; CONTRAST_OUTCOME="n/a"; TCC_VERSION_LINE="(not built)"

# ── the mescc -D argv, byte-faithful to R2 tcc.kaem:148-169 (CONFIG_*/TCC_* literals keep quotes
#    via the bash array). Only difference vs R2: -S output to tcc.s, which we KEEP. ──
mescc_argv() {
  MESCC_ARGS=(
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
}

# ── slice one function's body out of tcc.s (CWD = tcc tree) into $2. ──────────────────────────
# mescc/M1 emits a function as a COLUMN-0 label `:<name>` (M1.scm:278); in-function locals as
# `:_<name>_<n>_...` (compile.scm:1110). Start at `:<fn>`, print through all `:_<fn>_*` locals,
# STOP at the first OTHER column-0 `:identifier` (= the next function). Size-robust.
slice_fn() {
  local fn="$1" out="$2"
  /usr/bin/awk -v fn="$fn" '
    $0 == ":" fn { cap = 1 }
    cap && /^:[A-Za-z_]/ && $0 != ":" fn && index($0, ":_" fn "_") != 1 { exit }
    cap { print }
  ' tcc.s > "$out" 2>/dev/null
  local n b
  n=$(/usr/bin/wc -l < "$out" 2>/dev/null || echo 0)
  b=$(/usr/bin/wc -c < "$out" 2>/dev/null || echo 0)
  echo "ASM-RESULT $PHASE $fn lines=$n bytes=$b"
}

# ── compile tcc.c -> tcc.s (no link) from CURRENT x86_64-gen.c; capture full asm + slices. ──
# $1 = phase tag. Leaves tcc.s in the tcc tree for the link step. Returns 0 on success.
compile_and_slice() {
  PHASE="$1"
  cd "/build/$TCC_PKG" || { echo "FATAL[$PHASE] cannot cd into tcc tree"; return 1; }
  : > config.h
  mescc_argv
  echo "ASM-INFO[$PHASE] mescc tcc.c -> tcc.s (no-growth arena, ~250s long pole) ..."
  local t0=$SECONDS
  timeout "$STAGE_TIMEOUT" "$MES" --no-auto-compile -e main "$MESCC" -- "${MESCC_ARGS[@]}" \
    >"$WORK/$PHASE-compile.out" 2>"$WORK/$PHASE-compile.err"
  local rc=$?
  local lines; lines=$(/usr/bin/wc -l < tcc.s 2>/dev/null || echo 0)
  echo "ASM-INFO[$PHASE] mescc rc=$rc $((SECONDS-t0))s ($lines lines tcc.s)"
  if [ "$rc" != "0" ] || [ ! -s tcc.s ]; then
    echo "FATAL[$PHASE] mescc tcc.c->tcc.s FAILED (rc=$rc) >>> $(tail -4 "$WORK/$PHASE-compile.err" 2>/dev/null | tr '\n' '|')"
    return 1
  fi
  /usr/bin/gzip -c tcc.s > "$OUTROOT/tcc.s.$PHASE.gz"
  echo "ASM-INFO[$PHASE] full tcc.s gzipped -> tcc.s.$PHASE.gz ($(/usr/bin/wc -c < "$OUTROOT/tcc.s.$PHASE.gz") bytes)"
  for fn in "${SLICE_FNS[@]}"; do
    slice_fn "$fn" "$OUTROOT/$fn.$PHASE.s"
  done
  /usr/bin/grep -nE '^:|mov|lea|push|pop|add|sub|copy|imul|mul' "$OUTROOT/gfunc_call.$PHASE.s" \
    > "$OUTROOT/gfunc_call.$PHASE.labels-and-moves.txt" 2>/dev/null
  return 0
}

# ── link CURRENT tcc.s into tcc-mes; capture binary + gate on -version. Returns 0 on runnable. ──
link_binary() {
  PHASE="$1"
  cd "/build/$TCC_PKG" || return 1
  echo "ASM-INFO[$PHASE] mescc-link tcc.s -> tcc-mes ..."
  timeout "$LINK_TIMEOUT" "$MES" --no-auto-compile -e main "$MESCC" -- \
    --base-address 0x08048000 -o tcc-mes -L "$LIBDIR" tcc.s -l c+tcc \
    >"$WORK/$PHASE-link.out" 2>"$WORK/$PHASE-link.err"
  local rc=$?
  if [ "$rc" != "0" ] || [ ! -s tcc-mes ]; then
    echo "FATAL[$PHASE] link FAILED (rc=$rc) >>> $(tail -4 "$WORK/$PHASE-link.err" 2>/dev/null | tr '\n' '|')"
    return 1
  fi
  /usr/bin/cp tcc-mes "$OUTROOT/tcc-mes.$PHASE"
  /usr/bin/chmod 755 "$OUTROOT/tcc-mes.$PHASE"
  /usr/bin/cp tcc-mes "$BINDIR/" && /usr/bin/chmod 755 "$TCC"
  "$TCC" -version >"$WORK/$PHASE-version.out" 2>&1
  local rcv=$?
  TCC_VERSION_LINE=$(head -1 "$WORK/$PHASE-version.out" 2>/dev/null)
  echo "ASM-INFO[$PHASE] tcc-mes captured ($(/usr/bin/wc -c < "$OUTROOT/tcc-mes.$PHASE") bytes); -version rc=$rcv : $TCC_VERSION_LINE"
  [ "$rcv" = "0" ] || echo "WARN[$PHASE] tcc-mes -version rc=$rcv — continuing anyway (matrix + asm capture still run; do NOT skip)."
  return 0
}

# ── set up include/arch/ in the mes tree (must exist before any libc compile). ──
setup_mes_arch() {
  cd "/build/$MES_PKG" || { echo "FATAL cannot cd into mes tree"; return 1; }
  : > include/mes/config.h
  mkdir -p include/arch
  /usr/bin/cp "include/linux/$MES_ARCH/kernel-stat.h" include/arch/kernel-stat.h
  /usr/bin/cp "include/linux/$MES_ARCH/signal.h"      include/arch/signal.h
  /usr/bin/cp "include/linux/$MES_ARCH/syscall.h"     include/arch/syscall.h
  return 0
}

# ── classify one tcc-mes -c compile (rc + stderr signature + .o presence) into a bucket. ──
classify() {
  local rc="$1" errf="$2" obj="${3:-}"
  if [ "$rc" = "0" ]; then
    if [ -n "$obj" ] && [ ! -s "$obj" ]; then echo "OK-NOOBJ"; return; fi
    echo "OK"; return
  fi
  if /usr/bin/grep -qiE 'assert fail' "$errf" 2>/dev/null; then echo "ASSERTFAIL/SIGSEGV"; return; fi
  case "$rc" in
    139) echo "SIGSEGV(11)"; return ;;
    134) echo "SIGABRT(6)"; return ;;
    124) echo "TIMEOUT"; return ;;
  esac
  if /usr/bin/grep -qiE 'signal number = 11|abnormal termination' "$errf" 2>/dev/null; then echo "SIGSEGV(11)"; return; fi
  echo "OTHER($rc)"
}

# ── compile one source with the CURRENT tcc-mes (-c), bounded; emit a PROBE-RESULT row. ──
# Sets LAST_OUTCOME. CWD must be the MES_PKG root.
compile_unit() {
  local label="$1" src="$2" obj="$3" note="${4:-}"
  local safe="${label//\//_}"
  local errf="$WORK/${safe}.err"
  rm -f "$obj" "$errf"
  local bytes=0; [ -f "$src" ] && bytes=$(/usr/bin/wc -c < "$src" 2>/dev/null || echo 0)
  local t0=$SECONDS
  timeout "$PERUNIT_TIMEOUT" "$TCC" -c -D HAVE_CONFIG_H=1 -I include -I "include/linux/$MES_ARCH" \
    -o "$obj" "$src" >"$WORK/${safe}.out" 2>"$errf"
  local rc=$?
  local secs=$((SECONDS - t0))
  LAST_OUTCOME=$(classify "$rc" "$errf" "$obj")
  echo "PROBE-RESULT $label $LAST_OUTCOME ${secs}s rc=$rc bytes=$bytes $note"
  [ "$LAST_OUTCOME" = "OK" ] || echo "PROBE-ERRTAIL $label >>> $(tail -3 "$errf" 2>/dev/null | tr '\n' '|')"
}

# recompile the crasher set + contrast with the CURRENT tcc-mes; append name=outcome to $1's table.
run_matrix() {
  local tag="$1"           # A or B
  if ! setup_mes_arch; then echo "FATAL[$tag] could not set up include/arch/"; return 1; fi
  compile_unit "$tag-contrast-access(3arg)" "$CONTRAST" "$OBJDIR/access_$tag.o" "(MUST be OK)"
  [ "$tag" = "A" ] && CONTRAST_OUTCOME="$LAST_OUTCOME"
  for spec in "${CRASHERS[@]}"; do
    set -- $spec; local nm="$1" src="$2"
    compile_unit "$tag-$nm" "$src" "$OBJDIR/${nm}_$tag.o" "(>=4-arg call)"
    if [ "$tag" = "A" ]; then
      A_TABLE="$A_TABLE $nm=$LAST_OUTCOME"
    else
      if [ "$LAST_OUTCOME" = "OK" ]; then B_TABLE="$B_TABLE $nm=PASS"; else B_TABLE="$B_TABLE $nm=CRASH:$LAST_OUTCOME"; fi
    fi
  done
  return 0
}

# ════════════════════════════════════════════════════════════════════════════════════════════
echo "ASM-INFO begin: tcc-mes-asm-probe (A=capture canonical asm+binary; B=field-by-field FIX#2)"
echo "ASM-INFO mes-m2: $($MES --version 2>&1 | head -1 || true)"

if [ ! -f "$XGEN" ]; then { echo "FATAL: $XGEN missing (tcc Source did not extract?)"; } | tee "$MANIFEST"; exit 0; fi
if ! command -v simple-patch >/dev/null 2>&1; then { echo "FATAL: /usr/bin/simple-patch missing (stage0-mescc-full)"; } | tee "$MANIFEST"; exit 0; fi

# tcctools.c fopen relocation — applied in BOTH phases so the linked binary is byte-faithful to the
# production R2 tcc-mes (tcctools.c rides ONE_SOURCE=1). gfunc_call asm is independent of it. Non-fatal.
simple-patch "/build/$TCC_PKG/tcctools.c" /build/remove-fileopen.before /build/remove-fileopen.after \
  && simple-patch "/build/$TCC_PKG/tcctools.c" /build/addback-fileopen.before /build/addback-fileopen.after \
  && echo "ASM-INFO tcctools.c fopen patches applied (binary == R2)" \
  || echo "ASM-INFO WARN tcctools.c patch failed (binary differs from R2 in the -ar fopen path only)"

# snapshot the CANONICAL (gf-UNpatched, field-swap-UNpatched) x86_64-gen.c so PHASE-B resets clean.
/usr/bin/cp "$XGEN" "$PRISTINE"

# ── PHASE A: CANONICAL gfunc_call — capture asm + binary, PIN the crash baseline ──────────────
echo "ASM-INFO ===== PHASE A: canonical (unpatched) gfunc_call ====="
CANON_OK=0
if compile_and_slice canonical; then
  if link_binary canonical; then CANON_OK=1; run_matrix A; fi
fi
[ "$CANON_OK" = "1" ] || echo "FATAL PHASE-A failed — no canonical asm/baseline (see FATAL rows above)"

# ── PHASE B: FIX#2 field-by-field SValue swap — rebuild + matrix + capture patched asm/diff ────
echo "ASM-INFO ===== PHASE B: FIX#2 field-by-field SValue swap ====="
/usr/bin/cp "$PRISTINE" "$XGEN"
FIX_OK=1
for p in fix-swapf fix-swapb; do
  if simple-patch "$XGEN" "/build/$p.before" "/build/$p.after"; then
    echo "ASM-INFO applied $p (whole-struct swap -> per-field copies)"
  else
    echo "FATAL fix patch $p FAILED (before-pattern not found — byte drift vs pinned tcc tarball)"
    FIX_OK=0; break
  fi
done
PATCH_OK=0
if [ "$FIX_OK" = "1" ]; then
  if compile_and_slice patched; then
    if link_binary patched; then PATCH_OK=1; run_matrix B; fi
  fi
fi
if [ "$FIX_OK" != "1" ]; then
  for spec in "${CRASHERS[@]}"; do set -- $spec; B_TABLE="$B_TABLE $1=FIX-NOMATCH"; done
elif [ "$PATCH_OK" != "1" ]; then
  for spec in "${CRASHERS[@]}"; do set -- $spec; B_TABLE="$B_TABLE $1=BUILD-FAILED"; done
fi

# ── DIFF canonical-vs-patched gfunc_call (does FIX#2 change the struct-copy mov chains?) ───────
if [ "$CANON_OK" = "1" ] && [ "$PATCH_OK" = "1" ]; then
  /usr/bin/diff -u "$OUTROOT/gfunc_call.canonical.s" "$OUTROOT/gfunc_call.patched.s" \
    > "$OUTROOT/gfunc_call.canonical-vs-patched.diff" 2>/dev/null
  echo "ASM-INFO gfunc_call canonical-vs-patched diff = $(/usr/bin/wc -l < "$OUTROOT/gfunc_call.canonical-vs-patched.diff" 2>/dev/null || echo 0) lines"
  for fn in classify_x86_64_arg classify_x86_64_inner; do
    /usr/bin/diff -u "$OUTROOT/$fn.canonical.s" "$OUTROOT/$fn.patched.s" \
      > "$OUTROOT/$fn.canonical-vs-patched.diff" 2>/dev/null
  done
fi

# ── FINAL MATRIX + MANIFEST (to stdout AND OutputData) ────────────────────────────────────────
{
  echo "================ tcc-mes-asm-probe RESULT MATRIX ================"
  echo "host: $(/usr/bin/uname -a 2>/dev/null)"
  echo "tcc-mes: $TCC_VERSION_LINE"
  echo "mes-m2 arena: MES_ARENA=$MES_ARENA MES_MAX_ARENA=$MES_MAX_ARENA (no-growth)"
  echo "tcc: $TCC_PKG   active gfunc_call = SysV #else def (source ~1195-1473)"
  echo "FIX#2 = field-by-field SValue swap (fix-swapf + fix-swapb): the two whole-struct swaps in"
  echo "        gfunc_call's run loop become per-field copies. SValue field decomposition:"
  echo "          type.t(int4) type.ref(ptr8) r(u16) r2(u16) c(CValue union 16B) sym(ptr8) cmp_r(u16)"
  echo "        c is copied as a single 16B union assignment (mescc fast-path, 2 clean quads;"
  echo "        same construct as tccgen.c:644 'vtop->c=*vc') so NO 42-byte chunked mem->mem loop"
  echo "        and NO mod-8 tail/overrun path is taken for the swap."
  echo "------------------------------------------------------------------"
  printf 'PROBE-TABLE %-26s %s\n' "contrast access.c (3-arg)" "$CONTRAST_OUTCOME"
  echo "-- PHASE A (canonical tcc-mes) per-crasher: the CRASH baseline --"
  for spec in "${CRASHERS[@]}"; do set -- $spec; v=$(printf '%s\n' $A_TABLE | grep "^$1=" | head -1); printf 'PROBE-TABLE %-26s %s\n' "A $1" "${v#*=}"; done
  echo "-- PHASE B (FIX#2 field-by-field swap) per-crasher: PASS = compiled clean --"
  for spec in "${CRASHERS[@]}"; do set -- $spec; v=$(printf '%s\n' $B_TABLE | grep "^$1=" | head -1); printf 'PROBE-TABLE %-26s %s\n' "B $1" "${v#*=}"; done
  echo "------------------------------------------------------------------"
  echo "VERDICT LOGIC:"
  echo " * A all CRASH + B all PASS  => FIX#2 works: the 42-byte SValue STRUCT-COPY was the bug."
  echo "   Promote fix-swapf/fix-swapb into stage0-tcc-0.9.26 (replace gf-swapf/gf-swapb)."
  echo " * A all CRASH + B still CRASH => the struct-copy is NOT the (sole) bug; the variable-index"
  echo "   i*sizeof(SValue) scaling/spill on vtop[-i] survives field-by-field (each .field still"
  echo "   scales by i). Next: the POINTER-WALK variant (constant-stride pvi-- instead of vtop[-i])."
  echo " * A crash but contrast access.c=OK confirms the harness reproduces the >=4-arg wall."
  echo "------------------------------------------------------------------"
  echo "ASM ARTIFACTS in usr/share/tcc-mes-asm-probe/ :"
  for f in "$OUTROOT"/*; do
    [ "$f" = "$MANIFEST" ] && continue
    printf 'PROBE-TABLE %-46s %s bytes\n' "$(basename "$f")" "$(/usr/bin/wc -c < "$f" 2>/dev/null || echo 0)"
  done
  echo "------------------------------------------------------------------"
  echo "LOCAL ANALYSIS (retrieve from gs://minimalmertic-sign-staging/tcc-mes-asm-probe-a/usr/share/tcc-mes-asm-probe/):"
  echo "  less gfunc_call.canonical.s                  # M1/stage0 asm: the assert@1318 site + the SValue swap"
  echo "  less classify_x86_64_arg.canonical.s         # reads SValue.type@0 — the corrupted field"
  echo "  view gfunc_call.canonical-vs-patched.diff    # what FIX#2 changed in the emitted asm"
  echo "  gunzip tcc.s.canonical.gz                     # full ~123k-line emitted asm"
  echo "  nm tcc-mes.canonical | grep gfunc_call        # then: objdump -d --start-address=<addr> tcc-mes.canonical"
  echo "NOTE: the .s slices are M1 macro-assembly (NOT GNU-as). objdump the tcc-mes BINARY, read the .s SLICES directly."
  echo "================================================================"
} | tee "$MANIFEST"

echo "ASM-INFO manifest written to $MANIFEST"
exit 0
