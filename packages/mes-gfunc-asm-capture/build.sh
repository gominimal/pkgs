#!/usr/bin/env bash
# mes-gfunc-asm-capture — GROUND-TRUTH forensics probe. See build.ncl for the rationale.
#
# Builds the amd64 tcc-mes via R2's now-reliable no-growth-arena mescc path and CAPTURES, as
# retrievable OutputData artifacts, the mescc-EMITTED ASSEMBLY (tcc.s, M1/stage0 syntax) for the
# functions implicated in the >=4-arg-call SIGSEGV — gfunc_call (the assert@1318 site + the SValue
# struct-copy swap) and classify_x86_64_arg/inner/merge — PLUS the linked tcc-mes binary (for local
# objdump -d). It does so TWICE: once for the CANONICAL (un-gf-patched) gfunc_call, once for the
# gf-*-patched gfunc_call, and DIFFS the two slices so the addressing fix's exact instruction delta
# (and the byte-identity of the suspect struct-copy) is visible without a cloud rebuild.
#
# Greppable markers:
#   CAPTURE-INFO   ...                                   progress / phases
#   CAPTURE-RESULT <phase> <fn> lines=<n> bytes=<n>      one per sliced function
#   CAPTURE-FATAL  ...                                   a build step failed (still exits 0)
#   CAPTURE-TABLE  ...                                   final manifest rows
# Harness ALWAYS exits 0 (a diagnostic probe is not a trust rung).
set +e
set -u

# ── constant env (MUST match the production R2 tcc.kaem so the captured asm == the real build) ──
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

STAGEA_TIMEOUT=600        # bound each ~250s mescc tcc.c->tcc.s long pole (we run it TWICE)
LINK_TIMEOUT=300

XGEN=/build/$TCC_PKG/x86_64-gen.c
PRISTINE=/build/x86_64-gen.c.pristine

OUTROOT=/build/output/usr/share/mes-gfunc-asm-capture
mkdir -p "$OUTROOT" "$BINDIR" "$LIBDIR"
WORK=/build/capture-logs
mkdir -p "$WORK"
MANIFEST="$OUTROOT/MANIFEST.txt"

# The functions to slice out of tcc.s. gfunc_call (SysV #else def, source ~1195-1473) carries the
# assert@1318 (mode==x86_64_mode_sse) AND the 3 SValue struct-copies of the fwd/back swap; the
# classify_* trio is what gfunc_call calls at every vtop[-i].type site.
SLICE_FNS=(gfunc_call classify_x86_64_arg classify_x86_64_inner classify_x86_64_merge gfunc_prolog)

# ── the mescc -D argv, byte-faithful to R2 tcc.kaem:148-169 (CONFIG_*/TCC_* literals keep their
#    quotes via the bash array). Only difference vs R2: -S output goes to tcc.s and we KEEP it. ──
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

# ── slice one function's body out of tcc.s (CWD = the tcc tree) into $2. ───────────────────────
# mescc/M1 emits a function as a COLUMN-0 label line `:<name>` (module/mescc/M1.scm:278), and every
# in-function local label as `:_<name>_<n>_...` (module/mescc/compile.scm:1110). So: start at the
# `:<fn>` line, print through every `:_<fn>_*` local label, and STOP at the first OTHER column-0
# `:identifier` (= the next function). Robust to function size; no fixed window guess.
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
  echo "CAPTURE-RESULT $PHASE $fn lines=$n bytes=$b"
}

# ── compile tcc.c -> tcc.s (no link) from the CURRENT x86_64-gen.c, then slice every SLICE_FN. ──
# $1 = phase tag (canonical|patched). Leaves tcc.s in the tcc tree for the optional link step.
compile_and_slice() {
  PHASE="$1"
  cd "/build/$TCC_PKG" || { echo "CAPTURE-FATAL[$PHASE] cannot cd into tcc tree"; return 1; }
  : > config.h
  mescc_argv
  echo "CAPTURE-INFO[$PHASE] mescc tcc.c -> tcc.s (no-growth arena, ~250s long pole) ..."
  local t0=$SECONDS
  timeout "$STAGEA_TIMEOUT" "$MES" --no-auto-compile -e main "$MESCC" -- "${MESCC_ARGS[@]}" \
    >"$WORK/$PHASE-compile.out" 2>"$WORK/$PHASE-compile.err"
  local rc=$?
  local lines; lines=$(/usr/bin/wc -l < tcc.s 2>/dev/null || echo 0)
  echo "CAPTURE-INFO[$PHASE] mescc rc=$rc $((SECONDS-t0))s ($lines lines tcc.s)"
  if [ "$rc" != "0" ] || [ ! -s tcc.s ]; then
    echo "CAPTURE-FATAL[$PHASE] mescc tcc.c->tcc.s FAILED (rc=$rc) >>> $(tail -4 "$WORK/$PHASE-compile.err" 2>/dev/null | tr '\n' '|')"
    return 1
  fi
  # the full asm (gzipped — ~123k lines / several MB raw) + each implicated function's slice
  /usr/bin/gzip -c tcc.s > "$OUTROOT/tcc.s.$PHASE.gz"
  echo "CAPTURE-INFO[$PHASE] full tcc.s gzipped -> tcc.s.$PHASE.gz ($(/usr/bin/wc -c < "$OUTROOT/tcc.s.$PHASE.gz") bytes)"
  for fn in "${SLICE_FNS[@]}"; do
    slice_fn "$fn" "$OUTROOT/$fn.$PHASE.s"
  done
  # convenience: the assert@1318 / struct-copy neighbourhood — every label inside the gfunc_call
  # slice plus the bytes of stack arithmetic, so the human can jump straight to the swap.
  /usr/bin/grep -nE '^:|mov|lea|push|pop|add|sub|copy' "$OUTROOT/gfunc_call.$PHASE.s" \
    > "$OUTROOT/gfunc_call.$PHASE.labels-and-moves.txt" 2>/dev/null
  return 0
}

# ── link the CURRENT tcc.s into a tcc-mes binary (for local objdump -d) + capture it. ──────────
link_binary() {
  PHASE="$1"
  cd "/build/$TCC_PKG" || return 1
  echo "CAPTURE-INFO[$PHASE] mescc-link tcc.s -> tcc-mes ..."
  timeout "$LINK_TIMEOUT" "$MES" --no-auto-compile -e main "$MESCC" -- \
    --base-address 0x08048000 -o tcc-mes -L "$LIBDIR" tcc.s -l c+tcc \
    >"$WORK/$PHASE-link.out" 2>"$WORK/$PHASE-link.err"
  local rc=$?
  if [ "$rc" != "0" ] || [ ! -s tcc-mes ]; then
    echo "CAPTURE-FATAL[$PHASE] link FAILED (rc=$rc) >>> $(tail -4 "$WORK/$PHASE-link.err" 2>/dev/null | tr '\n' '|')"
    return 1
  fi
  /usr/bin/cp tcc-mes "$OUTROOT/tcc-mes.$PHASE"
  /usr/bin/chmod 755 "$OUTROOT/tcc-mes.$PHASE"
  echo "CAPTURE-INFO[$PHASE] tcc-mes captured ($(/usr/bin/wc -c < "$OUTROOT/tcc-mes.$PHASE") bytes)"
  # non-fatal sanity: does the freshly-built compiler at least run -version? (the R2 gate)
  /usr/bin/cp tcc-mes "$BINDIR/" && /usr/bin/chmod 755 "$BINDIR/tcc-mes"
  "$BINDIR/tcc-mes" -version >"$WORK/$PHASE-version.out" 2>&1
  echo "CAPTURE-INFO[$PHASE] tcc-mes -version rc=$? : $(head -1 "$WORK/$PHASE-version.out" 2>/dev/null)"
  return 0
}

# ════════════════════════════════════════════════════════════════════════════════════════════
echo "CAPTURE-INFO begin: capture gfunc_call asm (canonical + gf-patched) + tcc-mes binaries"
echo "CAPTURE-INFO mes-m2: $($MES --version 2>&1 | head -1 || true)"

if [ ! -f "$XGEN" ]; then
  { echo "FATAL: $XGEN missing (tcc Source did not extract?)"; } | tee "$MANIFEST"
  exit 0
fi
if ! command -v simple-patch >/dev/null 2>&1; then
  { echo "FATAL: /usr/bin/simple-patch not found (stage0-mescc-full missing)"; } | tee "$MANIFEST"
  exit 0
fi

# tcctools.c fopen relocation — applied in BOTH phases so the linked binary is byte-faithful to
# the production R2 tcc-mes (tcctools.c is compiled in via ONE_SOURCE=1). gfunc_call asm is wholly
# independent of these, so the gfunc_call SLICE is unaffected either way; we apply them so the
# objdump'd binary == R2's. Non-fatal.
simple-patch "/build/$TCC_PKG/tcctools.c" /build/remove-fileopen.before /build/remove-fileopen.after \
  && simple-patch "/build/$TCC_PKG/tcctools.c" /build/addback-fileopen.before /build/addback-fileopen.after \
  && echo "CAPTURE-INFO tcctools.c fopen patches applied (binary == R2)" \
  || echo "CAPTURE-INFO WARN tcctools.c patch failed (binary differs from R2 in the -ar fopen path only)"

# snapshot the CANONICAL x86_64-gen.c (gf-UNpatched) so PHASE-2 can reset cleanly.
/usr/bin/cp "$XGEN" "$PRISTINE"

# ── PHASE 1: CANONICAL (gf-UNpatched) gfunc_call ──────────────────────────────────────────────
echo "CAPTURE-INFO PHASE-1 canonical (un-gf-patched) gfunc_call"
CANON_OK=0
if compile_and_slice canonical; then
  link_binary canonical
  CANON_OK=1
else
  echo "CAPTURE-FATAL PHASE-1 compile failed — no canonical asm"
fi

# ── PHASE 2: gf-*-patched gfunc_call (the committed 5-site addressing fix that STILL crashes) ──
echo "CAPTURE-INFO PHASE-2 gf-patched gfunc_call (cache vtop-i into a local SValue* at 5 sites)"
/usr/bin/cp "$PRISTINE" "$XGEN"
GF_OK=1
for p in gf-count gf-clf gf-swapf gf-swapb gf-trail; do
  if simple-patch "$XGEN" "/build/$p.before" "/build/$p.after"; then
    echo "CAPTURE-INFO applied $p"
  else
    echo "CAPTURE-FATAL gf patch $p FAILED (before-pattern not found — byte drift vs pinned tcc)"
    GF_OK=0; break
  fi
done
PATCH_OK=0
if [ "$GF_OK" = "1" ]; then
  if compile_and_slice patched; then
    link_binary patched
    PATCH_OK=1
  else
    echo "CAPTURE-FATAL PHASE-2 compile failed — no patched asm"
  fi
fi

# ── DIFF the two gfunc_call slices (the headline artifact: what the 5-site fix changed, and
#    whether the SValue struct-copy instructions are byte-identical between them). ──────────────
if [ "$CANON_OK" = "1" ] && [ "$PATCH_OK" = "1" ]; then
  /usr/bin/diff -u "$OUTROOT/gfunc_call.canonical.s" "$OUTROOT/gfunc_call.patched.s" \
    > "$OUTROOT/gfunc_call.canonical-vs-patched.diff" 2>/dev/null
  dl=$(/usr/bin/wc -l < "$OUTROOT/gfunc_call.canonical-vs-patched.diff" 2>/dev/null || echo 0)
  echo "CAPTURE-INFO gfunc_call canonical-vs-patched diff = $dl lines"
  for fn in classify_x86_64_arg classify_x86_64_inner; do
    /usr/bin/diff -u "$OUTROOT/$fn.canonical.s" "$OUTROOT/$fn.patched.s" \
      > "$OUTROOT/$fn.canonical-vs-patched.diff" 2>/dev/null
  done
fi

# ── MANIFEST (to stdout + artifact) ───────────────────────────────────────────────────────────
{
  echo "================ mes-gfunc-asm-capture MANIFEST ================"
  echo "host: $(/usr/bin/uname -a 2>/dev/null)"
  echo "mes-m2 arena: MES_ARENA=$MES_ARENA MES_MAX_ARENA=$MES_MAX_ARENA (no-growth)"
  echo "tcc: $TCC_PKG   active gfunc_call = SysV #else def (source ~1195-1473)"
  echo "label format: function = column-0 ':<name>'  (M1.scm:278); locals = ':_<name>_<n>_' (compile.scm:1110)"
  echo "----------------------------------------------------------------"
  echo "ARTIFACTS in usr/share/mes-gfunc-asm-capture/ :"
  for f in "$OUTROOT"/*; do
    [ "$f" = "$MANIFEST" ] && continue
    printf 'CAPTURE-TABLE %-44s %s bytes\n' "$(basename "$f")" "$(/usr/bin/wc -c < "$f" 2>/dev/null || echo 0)"
  done
  echo "----------------------------------------------------------------"
  echo "LOCAL ANALYSIS (after retrieval from gs://minimalmertic-sign-staging/mes-gfunc-asm-capture-a/):"
  echo "  gunzip tcc.s.canonical.gz                          # full ~123k-line emitted asm"
  echo "  less gfunc_call.canonical.s                        # the gfunc_call body (assert@1318 + the SValue swap)"
  echo "  view  gfunc_call.canonical-vs-patched.diff         # what the 5-site addressing fix changed"
  echo "  objdump -d -M intel tcc-mes.patched | less         # the linked crasher (static ELF)"
  echo "  objdump -d tcc-mes.patched --start-address=... ... # narrow to gfunc_call (use 'nm tcc-mes.patched | grep gfunc_call')"
  echo "INTERPRETATION HINTS:"
  echo " * The SValue swap 'vtop[0]=*pvi; *pvi=tmp;' is THREE struct copies of a ~48-64B SValue."
  echo "   In gfunc_call.*.s look for the contiguous mov/lea chain (or a copy/mem->mem loop) that"
  echo "   moves type.t (offset 0, 4 bytes) + ref/r/r2/c/sym/cmp_r. A short copy (missing the high"
  echo "   field) or an off-by-one base register = the type-corruption smoking gun."
  echo " * If gfunc_call.canonical-vs-patched.diff touches ONLY the vtop[-i] address arithmetic"
  echo "   and the struct-copy mov chains are byte-IDENTICAL, that CONFIRMS R2's persistent crash"
  echo "   is the struct-copy (not the addressing the committed fix changed) — author a field-by-"
  echo "   field swap next, not another addressing tweak."
  echo "================================================================"
} | tee "$MANIFEST"

echo "CAPTURE-INFO manifest written to $MANIFEST"
exit 0
