#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────────────────────────────
# tcc-codegen-probe — THE STANDING codegen-bug rapid-isolation harness for the amd64 tcc-0.9.27 spine.
# DRAFT 2026-06-30. Systematizes how the A/B/C static-link/codegen bugs were caught (s2a..s2i bisection +
# diaggot.sh) into a reusable, growing instrument that the operator fires the instant R5/R6/.../R11 throws
# a codegen failure. Component (a) of the toolkit; it RUNS component (b) — the reproducer LIBRARY.
#
# WHAT IT DOES: compiles every repro/<name>.c with the SEALED tcc-musl2 (s4) — EXACTLY the way R5+ do it
# (the musl-cc wrapper, libc-twice -static link) — RUNS each binary, compares stdout to <name>.expected,
# and on ANY divergence SAVES the failing .o(s) + the linked binary so the operator can `objdump -d` the
# bad codegen locally (the asmdiff input). It is the regression suite for every amd64 bug we already found
# by RUNNING a binary, AND the early-warning net for the next one (shapes seeded ahead of binutils/gcc).
#
# PROBE, NOT A GATE. s4 is the seal (fail-shut). This is the INVESTIGATION tool: guaranteed-DONE so it is
# never auto-retried and always ships its greppable rows + saved artifacts. Three hard rules, all learned:
#   1. set +e / never abort / ALWAYS exit 0, every OutputData glob pre-populated at t=0  (tcc-0.9.27-diag).
#   2. RECORD child crashes as `exit=<code>`, NEVER the literal `rc=139` — and emit NO `mescc`/`mes-m2`/
#      `tcc.c->tcc.s` token near a SIGSEGV — or categorize_stderr (orch-queue lib.rs:453-468) false-flags
#      MesccArenaLottery and auto-retries this probe forever (the diag's hard-won lesson).
#   3. DETERMINISTIC: tcc-musl2 is musl-linked/stable (no mes-libc lottery) → every FAIL here is a REAL,
#      reproducible codegen bug indicting tcc-0.9.27 source. No retry will "fix" it; isolate + patch tcc.
# ─────────────────────────────────────────────────────────────────────────────────────────────────────
set +e
set -u

TCC=${PROBE_CC:-/usr/bin/tcc-musl2}          # candidate compiler under test (default: the s4-sealed one)
LT=/usr/lib/tcc/libtcc1.a
OUTROOT=/build/output/usr/share/tcc-codegen-probe
WORK=/build/cg
mkdir -p "$OUTROOT" "$WORK/save"
MAN="$OUTROOT/MANIFEST.txt"
emit(){ echo "$1"; echo "$1" >> "$WORK/rows.txt"; }

# ── guarantee every OutputData glob is non-empty from t=0 (DA-free, decoupled from any crash-prone compile) ──
echo "tcc-codegen-probe: results pending (see rows.log / FAIL-INDEX.txt)" > "$MAN"
echo "tcc-codegen-probe rows — populated as the probe runs"               > "$OUTROOT/rows.log"
: > "$OUTROOT/FAIL-INDEX.txt"
echo "no failing artifacts (all cases passed, or the probe aborted before any case ran)" > "$WORK/save/README"

# ── terminal path: flush rows to the manifest + saved-artifact index, exit 0 (probe is always DONE) ──
finish(){
  cp "$WORK/rows.txt" "$OUTROOT/rows.log" 2>/dev/null
  # bundle the failing objects/binaries for local objdump (the asmdiff inputs)
  ( cd "$WORK" && tar czf "$OUTROOT/saved-artifacts.tgz" save 2>/dev/null ) || true
  {
    echo "================= tcc-codegen-probe RESULT ================="
    echo "compiler under test: $TCC  ($("$TCC" -version 2>&1 | head -1))"
    echo "PASS=$PASS  FAIL=$FAIL  TOTAL=$TOTAL"
    echo "----- rows (greppable on stdout too: 'CG-CASE') -----"
    grep -E '^CG-' "$WORK/rows.txt" 2>/dev/null
    echo "-----------------------------------------------------------"
    if [ "${FAIL:-0}" != 0 ]; then
      echo "FAILING SHAPES (a latent tcc-0.9.27 amd64 codegen bug — DETERMINISTIC, not a lottery):"
      cat "$OUTROOT/FAIL-INDEX.txt"
      echo "NEXT (minutes, not days): pull saved-artifacts.tgz, then on the fetcher VM (real amd64, DA-free):"
      echo "  1. tcc-cmpcc.sh   repro/<shape>.c     # confirm tcc-vs-gcc DIVERGENCE (the differential oracle)"
      echo "  2. tcc-ddmin.sh   <the real .c>        # shrink the offending binutils/gcc TU to a <50-line repro"
      echo "  3. tcc-asmdiff.sh repro/<shape>.c <fn> # pin the exact bad instruction vs gcc -O0"
      echo "  4. add the shrunk .c+.expected to repro/, write the tcc.c source patch, re-run this probe."
    else
      echo "ALL CASES PASS — tcc-musl2 codegen is sound over the current library. Grow it before each new rung."
    fi
    echo "==========================================================="
  } | tee "$MAN"
  exit 0
}

# tag: the //shape: marker on line 1 of each case (bug-class provenance: which fix it guards)
tag(){ grep -m1 '^//shape:' "$WORK/repro/repro/$1.c" 2>/dev/null | sed 's,//shape:,,' | tr -d '\n'; }
# save: stash the failing object(s) + greppable index entry for local objdump
save(){ local c="$1"
  cp "$WORK/$c.o"     "$WORK/save/$c.o"     2>/dev/null
  cp "$WORK/$c.lib.o" "$WORK/save/$c.lib.o" 2>/dev/null
  echo "$c   shape=$(tag "$c")" >> "$OUTROOT/FAIL-INDEX.txt"
}

# run_case: compile-only (isolate compile crash) → link via musl-cc (faithful R5+ path) → run → compare.
run_case(){ local c="$1"
  TOTAL=$((TOTAL+1))
  local R="$WORK/repro/repro"
  local src="$R/$c.c" lib="$R/$c.lib.c" exp="$R/$c.expected"
  rm -f "$WORK/bin" "$WORK/$c.o" "$WORK/$c.lib.o"
  "$TCC" -c -o "$WORK/$c.o" "$src" 2>"$WORK/$c.cc.err"; local cc=$?
  if [ "$cc" != 0 ]; then
    emit "CG-CASE $c COMPILE-FAIL exit=$cc [$(tag "$c")] >>> $(tail -1 "$WORK/$c.cc.err" 2>/dev/null | tr '\n' '|')"
    FAIL=$((FAIL+1)); save "$c"; return
  fi
  local objs="$WORK/$c.o"
  if [ -f "$lib" ]; then
    "$TCC" -c -o "$WORK/$c.lib.o" "$lib" 2>>"$WORK/$c.cc.err"
    objs="$objs $WORK/$c.lib.o"
  fi
  # shellcheck disable=SC2086
  "$MUSLCC" $objs -o "$WORK/bin" 2>"$WORK/$c.ld.err"; local lk=$?
  if [ "$lk" != 0 ]; then
    emit "CG-CASE $c LINK-FAIL exit=$lk [$(tag "$c")] >>> $(tail -1 "$WORK/$c.ld.err" 2>/dev/null | tr '\n' '|')"
    FAIL=$((FAIL+1)); save "$c"; return
  fi
  local act rrc want
  act="$(timeout 15 "$WORK/bin" 2>&1)"; rrc=$?
  want="$(cat "$exp" 2>/dev/null)"
  if [ "$rrc" = 0 ] && [ "$act" = "$want" ]; then
    emit "CG-CASE $c PASS [$(tag "$c")]"; PASS=$((PASS+1))
  else
    # RAN-WRONG (codegen value bug) or CRASH (codegen control-flow bug) — the highest-value signal.
    emit "CG-CASE $c FAIL exit=$rrc [$(tag "$c")]  got1='$(echo "$act" | head -1)'  want1='$(echo "$want" | head -1)'"
    cp "$WORK/bin" "$WORK/save/$c.bin" 2>/dev/null
    FAIL=$((FAIL+1)); save "$c"
  fi
}

PASS=0; FAIL=0; TOTAL=0
emit "CG-INFO compiler under test: $TCC  ($("$TCC" -version 2>&1 | head -1))"
emit "CG-INFO libtcc1.a=$(wc -c < "$LT" 2>/dev/null | tr -d ' ')B  libc.a=$(wc -c < /usr/lib/libc.a 2>/dev/null | tr -d ' ')B  crt1.o=$(test -f /usr/lib/crt1.o && echo yes || echo NO)  stdio.h=$(test -f /usr/include/stdio.h && echo yes || echo NO)"

# ── the R5/R6 musl-cc wrapper, VERBATIM from stage0-binutils-2.30/build.sh:36-43 (faithful link order) ──
cat > "$WORK/musl-cc" <<WRAP
#!/bin/sh
for a in "\$@"; do case "\$a" in -c|-S|-E) exec $TCC "\$@" ;; esac; done
exec $TCC -nostdlib -static /usr/lib/crt1.o /usr/lib/crti.o "\$@" \\
  /usr/lib/libc.a $LT /usr/lib/libc.a /usr/lib/crtn.o
WRAP
chmod 755 "$WORK/musl-cc"; MUSLCC="$WORK/musl-cc"

# ── preflight (fatal: nothing can run without the compiler + musl crt/libc) ──
[ -x "$TCC" ]            || { emit "CG-FATAL tcc-musl2 missing/not-executable (s4 did not deliver)"; finish; }
[ -f "$LT" ]            || { emit "CG-FATAL libtcc1.a missing (s4 did not deliver)"; finish; }
[ -f /usr/lib/crt1.o ]  || { emit "CG-FATAL musl crt1.o missing (R4 did not deliver)"; finish; }
[ -f /build/repro.tar.gz ] || { emit "CG-FATAL repro.tar.gz missing (Local build_dep)"; finish; }

# ── extract the reproducer library ──
mkdir -p "$WORK/repro"; ( cd "$WORK/repro" && tar --no-same-owner -xzf /build/repro.tar.gz ) 2>/dev/null
[ -d "$WORK/repro/repro" ] || { emit "CG-FATAL repro/ dir absent after extract"; finish; }

# ── RUN THE WHOLE LIBRARY (every <name>.c that is not a <name>.lib.c companion) ──
emit "CG-INFO ===== running reproducer library against $TCC ====="
for f in "$WORK"/repro/repro/*.c; do
  case "$f" in *.lib.c) continue;; esac
  b="$(basename "${f%.c}")"
  run_case "$b"
done
emit "CG-SUMMARY $PASS/$TOTAL passed, $FAIL failed"

finish
