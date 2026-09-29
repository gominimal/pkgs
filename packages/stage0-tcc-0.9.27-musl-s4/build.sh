#!/usr/bin/env bash
# stage0-tcc-0.9.27-musl-s4: correctness gate for s3's tcc-musl2. Every gate must pass before the
# blessed /usr/bin/tcc-musl2 is written; otherwise it stays absent and the build exits non-zero.
# tcc-musl2 is musl-linked, so a failure here is deterministic: rebuild s3, do not retry s4.
# phases: preflight, self-hosting fixed point (C2==C3), torture suite, verdict.
set +e
set -u
BUILDROOT="$(pwd)"
TM2=/usr/bin/tcc-musl2            # s3: the musl-linked candidate compiler under test
LT=/usr/lib/tcc/libtcc1.a        # s3: x86_64 libtcc1.a (also under test via the torture helpers)
# Single-writer musl sysroot from stage0-musl-1.1.24-cc2. The merged /usr/include and /usr/lib/libc.a
# are a first-writer-wins draw against the glibc runtime dep of the shell tools, so every musl
# compile/link below uses -nostdinc -I "$MI" and -nostdlib + explicit crt/libc from "$ML".
MB=/usr/lib/musl-bedrock; MI="$MB/include"; ML="$MB/lib"
OUT=/build/output; BINOUT=$OUT/usr/bin; LIBOUT=$OUT/usr/lib/tcc; LOGOUT=$OUT/usr/share/tcc-musl-s4
mkdir -p "$LOGOUT" /build/g
MAN="$LOGOUT/MANIFEST.txt"
emit(){ echo "$1"; echo "$1" >> /build/g/rows.txt; }
GATEFAIL=0
gate_fail(){ GATEFAIL=1; emit "S4-GATE-FAIL $1"; }   # marks failure without exiting, so every gate runs

sha(){ sha256sum "$1" 2>/dev/null | cut -c1-64; }

# failure path: write logs, leave no blessed binary, exit 1.
finish_fail(){
  cp /build/g/rows.txt "$LOGOUT/rows.log" 2>/dev/null
  {
    echo "============ stage0-tcc-0.9.27-musl-s4 — CORRECTNESS GATE: FAILED ============"
    grep S4- /build/g/rows.txt
    echo "------------------------------------------------------------------------------"
    echo "READ: a gate FAILED => tcc-musl2 did not pass => not published."
    echo "      Deterministic (tcc-musl2 is musl-linked and stable):"
    echo "      rebuilding this package reuses the SAME cached tcc-musl2 -> same verdict;"
    echo "      a retry does not help."
    echo "      FIX: the tcc-musl2 INPUT from stage0-tcc-0.9.27-musl-s3 is suspect (a wrong-but-running mes-libc build) ->"
    echo "      rebuild stage0-tcc-0.9.27-musl-s3 for a fresh"
    echo "      tcc-musl2, confirm S4-DETERM-INPUT-SHA changed, then rebuild this package."
    if grep -q "FIXPOINT C2 != C3" /build/g/rows.txt; then
      echo "      *** EXCEPTION — the failing gate is the C2 != C3 fixed point: this is a CODEGEN"
      echo "      *** NON-CONVERGENCE. Rebuilding stage0-tcc-0.9.27-musl-s3 will NOT help. Hunt the"
      echo "      *** unstable codegen with the oracle (tcc-cmpcc/ddmin/asmdiff): diff C2 vs C3 output"
      echo "      *** on tcc.c to localize which construct compiles to a non-reproducing binary."
    fi
    echo "      NO blessed /usr/bin/tcc-musl2 was produced (absent OutputBin => failed => no seal)."
  } | tee "$MAN"
  exit 1
}

emit "S4-INFO gate tcc-musl2 -> seal.  TM2=$("$TM2" -version 2>&1 | head -1)  CLEAN-musl(musl-1.1.24 $MB): libc.a=$(ls -la "$ML/libc.a" 2>/dev/null | awk '{print $5}')B stdio.h=$(test -f "$MI/stdio.h" && echo yes || echo NO)  libtcc1=$(ls -la $LT 2>/dev/null | awk '{print $5}')B  [merged /usr, glibc-polluted + UNUSED for musl compiles: libc.a=$(ls -la /usr/lib/libc.a 2>/dev/null | awk '{print $5}')B stdio.h=$(test -f /usr/include/stdio.h && echo yes || echo NO)]"

# ---- Preflight (fatal: cannot run any gate without these) --------------------------------------
[ -x "$TM2" ] || { gate_fail "tcc-musl2 missing/not-executable (s3 did not deliver)"; finish_fail; }
[ -f "$LT" ]  || { gate_fail "libtcc1.a missing (s3 did not deliver)"; finish_fail; }
# The clean sysroot is mandatory; without it the gate would read the drawn /usr and be nondeterministic.
{ [ -f "$MI/stdio.h" ] && [ -f "$ML/libc.a" ] && [ -f "$ML/crt1.o" ]; } || { gate_fail "clean musl sysroot missing/incomplete at $MB (stage0-musl-1.1.24-cc2 dependency: expected $MI/stdio.h + $ML/{libc.a,crt1.o,crti.o,crtn.o}). This package REQUIRES that usr/lib/musl-bedrock/{include,lib} sysroot so musl compiles never pick up glibc from /usr."; finish_fail; }
TM2SHA=$(sha "$TM2")
emit "S4-DETERM-INPUT-SHA tcc-musl2=$TM2SHA  (GATE 1: operator compares this across >=2 fresh-sandbox stage0-tcc-0.9.27-musl-s3 builds; must be byte-identical)"

# GATE A: tcc-musl2 itself runs.
"$TM2" -version >/tmp/v 2>&1; rc=$?
[ "$rc" = 0 ] && emit "S4-RUN tcc-musl2 -version rc=0 : $(head -1 /tmp/v)" || { gate_fail "tcc-musl2 -version rc=$rc : $(head -1 /tmp/v)"; finish_fail; }

# ---- GATE 2: self-hosting fixed point ----
# Generations: C1 = tcc-musl2 (s3 input), C2 = C1(tcc.c) = tcc-musl3, C3 = C2(tcc.c) = tcc-musl4.
# C1 may legitimately differ from C2: C1 was emitted by a mes-linked compiler, and libc-dependent
# codegen paths (qsort ties, snprintf) wash out after one generation. The gate is C2 == C3 and
# C2 is sealed. Byte identity requires identical flags for every generation (compile_tcc below);
# tcc.c embeds no __DATE__/__TIME__.
mkdir -p /build/g/tm; cd /build/g/tm
tar --no-same-owner -xzf "$BUILDROOT/tccsrc-r3gotABC.tar.gz" 2>/tmp/te || { gate_fail "extract tccsrc: $(head -1 /tmp/te)"; finish_fail; }
[ -d tccsrc ] || { gate_fail "no tccsrc dir (deterministic extract failure — fix the source)"; finish_fail; }
cd "$BUILDROOT"
TCCSRC=/build/g/tm/tccsrc

# compile_tcc OUT CC LOG: compile tcc.c -> OUT with CC from inside the tccsrc dir (uses -I .),
# with fixed flags so C2 and C3 use byte-identical invocations. Runs in a subshell.
compile_tcc(){
  local out="$1" cc="$2" log="$3"
  # -nostdinc -I "$MI": clean musl headers (musl ships its own stddef.h/stdarg.h/stdbool.h).
  # -nostdlib + crt1 crti <obj> libc.a libtcc1.a libc.a crtn: libc.a twice for the libtcc1<->libc
  # back-references (tcc has no --start-group). The baked -D CONFIG_* are the emitted tcc's
  # runtime paths and stay /usr/...; only this compile's own flags use the sysroot.
  ( cd "$TCCSRC" && : > config.h && "$cc" -w -nostdinc -nostdlib -static -o "$out" \
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
    -I . -I "$MI" \
    "$ML/crt1.o" "$ML/crti.o" \
    tcc.c \
    "$ML/libc.a" "$LT" "$ML/libc.a" \
    "$ML/crtn.o" 2>"$log" )
}

TM3=/build/g/tcc-musl3            # C2 = C1(tcc.c)
TM4=/build/g/tcc-musl4            # C3 = C2(tcc.c)

# C2 = C1(tcc.c). A musl-linked compiler must not crash here.
compile_tcc "$TM3" "$TM2" /tmp/b3; bc=$?
if [ "$bc" != 0 ] || [ ! -x "$TM3" ]; then
  gate_fail "FIXPOINT compile C2 tcc.c->tcc-musl3 rc=$bc (a STABLE musl-linked compiler must NOT crash compiling tcc.c — tcc-musl2 is a bad mes-libc build): $(tail -3 /tmp/b3 2>/dev/null | tr '\n' '|')"
  finish_fail
fi
"$TM3" -version >/tmp/v3 2>&1; r3=$?
[ "$r3" = 0 ] && emit "S4-FP-RUN tcc-musl3 -version rc=0 : $(head -1 /tmp/v3)" || gate_fail "FIXPOINT C2 tcc-musl3 -version rc=$r3 (self-compiled compiler does not run): $(head -1 /tmp/v3)"

# C3 = C2(tcc.c).
compile_tcc "$TM4" "$TM3" /tmp/b4; bc4=$?
if [ "$bc4" != 0 ] || [ ! -x "$TM4" ]; then
  gate_fail "FIXPOINT compile C3 tcc.c->tcc-musl4 rc=$bc4 (the self-compiled C2 must be able to compile tcc.c — fixed-point compiler defect): $(tail -3 /tmp/b4 2>/dev/null | tr '\n' '|')"
  finish_fail
fi
"$TM4" -version >/tmp/v4 2>&1; r4=$?
[ "$r4" = 0 ] && emit "S4-FP-RUN tcc-musl4 -version rc=0 : $(head -1 /tmp/v4)" || gate_fail "FIXPOINT C3 tcc-musl4 -version rc=$r4 (self-compiled compiler does not run): $(head -1 /tmp/v4)"

TM3SHA=$(sha "$TM3")
TM4SHA=$(sha "$TM4")
emit "S4-FP-SHA C1/tcc-musl2=$TM2SHA C2/tcc-musl3=$TM3SHA C3/tcc-musl4=$TM4SHA"

# fixed point: C2 must reproduce itself bytewise.
if [ "$TM3SHA" = "$TM4SHA" ]; then
  emit "S4-FP-FIXPOINT PASS (C2==C3: tcc-musl3 reproduces itself bytewise — self-hosting fixed point reached; sealing C2)"
else
  gate_fail "FIXPOINT C2 != C3 (tcc-musl3 != tcc-musl4: the compiler does not converge — genuine wrong-but-running codegen defect, NOT the benign gen-0 mes-linked difference; hunt with the codegen oracle)"
fi

# Seal C2 (tcc-musl3's bytes) under the name tcc-musl2, which downstream CC wrappers expect.
SEALCC="$TM3"; SEALSHA="$TM3SHA"

# informational: C1 != C2 is the expected gen-0 washout; C1 == C2 means it already converged. Not a gate.
if [ "$TM2SHA" = "$TM3SHA" ]; then
  emit "S4-FP-GEN0 C1==C2 (gen-0 already converged; C0's mes-linking left no libc-dependent codegen residue)"
else
  emit "S4-FP-GEN0 C1 != C2 (benign gen-0 mes-linked washout — informational, not a failure; see GATE 2 comment)"
fi

# ---- GATE 3 (+ float): torture suite ----
# Compile each torture test with the sealed C2 (not the s3 input), run it, and require exit 0 and
# stdout == *.expected. $(...) strips trailing newlines from both sides, so no diffutils is needed.
mkdir -p /build/g/tort; cd /build/g/tort
tar --no-same-owner -xzf "$BUILDROOT/tcc-torture-s4.tar.gz" 2>/tmp/tte || { gate_fail "extract torture: $(head -1 /tmp/tte)"; finish_fail; }
[ -d torture ] || { gate_fail "no torture/ dir after extract"; finish_fail; }
TESTS="t_shift t_mul t_args t_varargs t_struct t_float t_longlong t_recursion t_bigframe t_switch t_setjmp"
pass=0; total=0
for t in $TESTS; do
  total=$((total+1))
  rm -f bin
  # same clean-sysroot invocation as compile_tcc.
  "$SEALCC" -nostdinc -nostdlib -static -I "$MI" -o bin \
    "$ML/crt1.o" "$ML/crti.o" "torture/$t.c" \
    "$ML/libc.a" "$LT" "$ML/libc.a" "$ML/crtn.o" 2>/tmp/ce; cc=$?
  if [ "$cc" != 0 ]; then gate_fail "TORTURE $t COMPILE rc=$cc : $(head -1 /tmp/ce)"; continue; fi
  act="$(timeout 15 ./bin 2>&1)"; rrc=$?
  exp="$(cat "torture/$t.expected")"
  if [ "$rrc" = 0 ] && [ "$act" = "$exp" ]; then
    pass=$((pass+1)); emit "S4-TORTURE $t PASS"
  else
    gate_fail "TORTURE $t RAN-WRONG rc=$rrc  got1='$(echo "$act" | head -1)'  want1='$(echo "$exp" | head -1)'"
  fi
done
# cross-object: a call to a defined global function in a separate object, linked -static (the
# static-PLT case). Two units -> two .o -> one link -> run.
total=$((total+1))
"$SEALCC" -c -nostdinc -I "$MI" -o xm.o torture/t_xobj_main.c 2>/tmp/cxm; m=$?
"$SEALCC" -c -nostdinc -I "$MI" -o xl.o torture/t_xobj_lib.c 2>/tmp/cxl; l=$?
"$SEALCC" -nostdlib -static -o xbin \
  "$ML/crt1.o" "$ML/crti.o" xm.o xl.o \
  "$ML/libc.a" "$LT" "$ML/libc.a" "$ML/crtn.o" 2>/tmp/cxlnk; lk=$?
if [ "$m" = 0 ] && [ "$l" = 0 ] && [ "$lk" = 0 ]; then
  act="$(timeout 15 ./xbin 2>&1)"; rrc=$?
  exp="$(cat torture/t_xobj.expected)"
  if [ "$rrc" = 0 ] && [ "$act" = "$exp" ]; then
    pass=$((pass+1)); emit "S4-TORTURE t_xobj PASS (cross-object defined-fn call / static-PLT)"
  else
    gate_fail "TORTURE t_xobj RAN-WRONG rc=$rrc (static-PLT regression?)  got1='$(echo "$act" | head -1)'"
  fi
else
  gate_fail "TORTURE t_xobj COMPILE/LINK m=$m l=$l lk=$lk : $(head -1 /tmp/cxlnk)"
fi
emit "S4-TORTURE-SUMMARY $pass/$total passed (float gate = t_float; static-PLT = t_xobj)"
cd "$BUILDROOT"

# ---- VERDICT: bless on FULL pass, else fail hard (no fake-success) ---------------------------------
if [ "$GATEFAIL" != 0 ]; then finish_fail; fi

# every gate passed: write the fixed-point compiler C2 as /usr/bin/tcc-musl2, its libtcc1.a and GATE-PASS.
mkdir -p "$BINOUT" "$LIBOUT"
cp "$SEALCC" "$BINOUT/tcc-musl2"
cp "$LT"  "$LIBOUT/libtcc1.a"
echo "PASS tcc-musl2=$SEALSHA fixedpoint=C2==C3(tcc-musl3==tcc-musl4) torture=$pass/$total" > "$LOGOUT/GATE-PASS"
cp /build/g/rows.txt "$LOGOUT/rows.log"
{
  echo "============ stage0-tcc-0.9.27-musl-s4 — CORRECTNESS GATE: ALL PASS ============"
  grep S4- /build/g/rows.txt
  echo "------------------------------------------------------------------------------"
  echo "SEAL: /usr/bin/tcc-musl2 = C2, the fixed-point compiler (tcc-musl3's bytes)  sha256=$SEALSHA"
  echo "      GATE 2 fixed point: C2==C3 (tcc-musl3==tcc-musl4) — C2 reproduces itself bytewise."
  echo "      GATE 3 torture: $pass/$total RAN with correct output on the published C2 (incl. static-PLT, varargs, longlong)."
  echo "      GATE 4 float: t_float strtod/printf-float correct against musl-1.1.24."
  echo "      GATE 1 determinism (operator): assert S4-DETERM-INPUT-SHA == across >=2 fresh stage0-tcc-0.9.27-musl-s3 builds."
  echo "      GATE 5 provenance (manifest): chain_enforce:true + overlay_active/retry_count recorded in the attestation."
  echo "      => tcc-musl2 passed every gate; it is the CC for binutils-2.30."
} | tee "$MAN"
exit 0
