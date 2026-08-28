#!/usr/bin/env bash
# DRAFT 2026-06-30 — operator review before wiring (see .staging-ctx/correctness-gate-2026-06-30.md).
#   All 12 torture expected-values were validated against a real compiler (Apple clang, -O0==-O2, LP64
#   ABI-invariant) and the big 64-bit values cross-checked against an independent Python oracle.
# R4a STAGE 4 — THE CORRECTNESS GATE. tcc-musl2 (from s3) must pass ALL gates before it is sealed in
# RemoteCache. s4 does NOT roll the mes-libc lottery: tcc-musl2 is musl-linked/stable, so any failure
# here is DETERMINISTIC and indicts the s3 tcc-musl2 INPUT -> re-roll s3 for a fresh one, do NOT retry s4
# (a re-enqueue reuses the SAME cached tcc-musl2 -> identical result). No fake-success cp (s1:20 lesson):
# the blessed /usr/bin/tcc-musl2 is written ONLY after every gate passes; otherwise it stays absent and
# the build exits non-zero. Mirrors s1/s3 hardening.
set +e
set -u
BUILDROOT="$(pwd)"
TM2=/usr/bin/tcc-musl2            # s3: the musl-linked CANDIDATE compiler under test
LT=/usr/lib/tcc/libtcc1.a        # s3: x86_64 libtcc1.a (also under test via the torture helpers). NOTE:
                                 # /usr/lib/tcc is s3's SOLE-writer path (glibc never writes it) — safe.
# CLEAN SINGLE-WRITER MUSL SYSROOT (R4b publishes /usr/lib/musl-bedrock/{include,lib}).  WHY: the bedrock's
# glibc-linked shell-tool deps (bash/coreutils/sed/grep/tar/gzip/gawk-bootstrap) each carry a `glibc`
# runtime_dep whose outputs ALSO include usr/include/** + usr/lib/libc.a.  minimal materializes the sandbox
# rootfs from an UNORDERED hash-set of dep dirs with FIRST-writer-wins collision handling, so whether musl
# (R4b) or glibc owns the MERGED /usr/include/stdio.h + /usr/lib/libc.a is a nondeterministic per-build
# coin-flip; when glibc wins, tcc-0.9.27 dies on glibc's stdio.h ("invalid type") and would link the wrong
# libc.  Every musl compile/link below therefore IGNORES the coin-flip /usr and uses this deterministic
# clean tree: -nostdinc -I "$MI" for headers, -nostdlib + explicit crt/libc from "$ML" for the link.
MB=/usr/lib/musl-bedrock; MI="$MB/include"; ML="$MB/lib"
OUT=/build/output; BINOUT=$OUT/usr/bin; LIBOUT=$OUT/usr/lib/tcc; LOGOUT=$OUT/usr/share/tcc-musl-s4
mkdir -p "$LOGOUT" /build/g
MAN="$LOGOUT/MANIFEST.txt"
emit(){ echo "$1"; echo "$1" >> /build/g/rows.txt; }
GATEFAIL=0
gate_fail(){ GATEFAIL=1; emit "S4-GATE-FAIL $1"; }   # marks failure, does NOT exit (run every gate for a full report)

sha(){ sha256sum "$1" 2>/dev/null | cut -c1-64; }

# Terminal failure path: write logs, leave NO blessed binary, exit 1 with operator guidance.
finish_fail(){
  cp /build/g/rows.txt "$LOGOUT/rows.log" 2>/dev/null
  {
    echo "============ stage0-tcc-0.9.27-musl-s4 — CORRECTNESS GATE: FAILED ============"
    grep S4- /build/g/rows.txt
    echo "------------------------------------------------------------------------------"
    echo "READ: a gate FAILED => tcc-musl2 is NOT trust-grade => DO NOT SEAL."
    echo "      DETERMINISTIC (tcc-musl2 is musl-linked/stable, not the mes-libc lottery):"
    echo "      re-enqueuing s4 reuses the SAME cached tcc-musl2 -> same verdict. This is NOT"
    echo "      a MesccArenaLottery; it is BuildScriptFailed (non-retryable)."
    echo "      FIX: the s3 tcc-musl2 INPUT is suspect (a ~5% wrong-but-running mes-libc roll) ->"
    echo "      re-roll s3 (orch enqueue stage0-tcc-0.9.27-musl-s3 --retry-on-lottery N) for a fresh"
    echo "      tcc-musl2, confirm S4-DETERM-INPUT-SHA changed, then re-run s4."
    if grep -q "FIXPOINT C2 != C3" /build/g/rows.txt; then
      echo "      *** EXCEPTION — the failing gate is the C2 != C3 fixed point: this is a CODEGEN"
      echo "      *** NON-CONVERGENCE, NOT an s3 lottery roll. Re-rolling s3 will NOT help. Hunt the"
      echo "      *** unstable codegen with the oracle (tcc-cmpcc/ddmin/asmdiff): diff C2 vs C3 output"
      echo "      *** on tcc.c to localize which construct compiles to a non-reproducing binary."
    fi
    echo "      NO blessed /usr/bin/tcc-musl2 was produced (absent OutputBin => failed => no seal)."
  } | tee "$MAN"
  exit 1
}

emit "S4-INFO gate tcc-musl2 -> seal.  TM2=$("$TM2" -version 2>&1 | head -1)  CLEAN-musl(R4b $MB): libc.a=$(ls -la "$ML/libc.a" 2>/dev/null | awk '{print $5}')B stdio.h=$(test -f "$MI/stdio.h" && echo yes || echo NO)  libtcc1=$(ls -la $LT 2>/dev/null | awk '{print $5}')B  [merged /usr, glibc-polluted + UNUSED for musl compiles: libc.a=$(ls -la /usr/lib/libc.a 2>/dev/null | awk '{print $5}')B stdio.h=$(test -f /usr/include/stdio.h && echo yes || echo NO)]"

# ---- Preflight (fatal: cannot run any gate without these) --------------------------------------
[ -x "$TM2" ] || { gate_fail "tcc-musl2 missing/not-executable (s3 did not deliver)"; finish_fail; }
[ -f "$LT" ]  || { gate_fail "libtcc1.a missing (s3 did not deliver)"; finish_fail; }
# The clean R4b musl sysroot is MANDATORY: without it we would fall back to the coin-flip /usr and the gate
# would be nondeterministic.  Absence is a broken R4b edge (R4b must publish usr/lib/musl-bedrock), NOT a
# lottery — fail hard as BuildScriptFailed.
{ [ -f "$MI/stdio.h" ] && [ -f "$ML/libc.a" ] && [ -f "$ML/crt1.o" ]; } || { gate_fail "clean musl sysroot missing/incomplete at $MB (broken R4b edge: expected $MI/stdio.h + $ML/{libc.a,crt1.o,crti.o,crtn.o}). s4 REQUIRES R4b's usr/lib/musl-bedrock/{include,lib} to avoid the glibc /usr coin-flip."; finish_fail; }
TM2SHA=$(sha "$TM2")
emit "S4-DETERM-INPUT-SHA tcc-musl2=$TM2SHA  (GATE 1: operator compares this across >=2 fresh-sandbox s3 rolls; must be byte-identical)"

# GATE A — baseline: tcc-musl2 itself runs. (cheap; a crash here is fatal, nothing else can run)
"$TM2" -version >/tmp/v 2>&1; rc=$?
[ "$rc" = 0 ] && emit "S4-RUN tcc-musl2 -version rc=0 : $(head -1 /tmp/v)" || { gate_fail "tcc-musl2 -version rc=$rc : $(head -1 /tmp/v)"; finish_fail; }

# ---- GATE 2: SELF-HOSTING FIXED POINT --------------------------------------------------------------
# The self-hosting fixed point is C2==C3, NOT C1==C2. The bootstrap generations:
#   C0 = tcc-musl  (s1)         — MES-LINKED bootstrap compiler (not present here; context only)
#   C1 = tcc-musl2 (s3, $TM2)   — C0(tcc.c), musl-linked. This stage's INPUT.
#   C2 = tcc-musl3 ($TM3)       — C1(tcc.c)
#   C3 = tcc-musl4 ($TM4)       — C2(tcc.c)
# C1 may LEGITIMATELY differ from C2: C0 is mes-*LINKED*, so any codegen path that consults libc
# (qsort tie-breaking, snprintf, hash/iteration order) can differ between mes-libc (in C0) and musl
# (in C1), and that gen-0 difference washes out by C2. A C1==C2 gate therefore FAILS even on a CORRECT
# compiler. The standard 3-stage bootstrap fixed point is C2==C3: a musl-linked compiler that
# reproduces ITSELF bytewise. We GATE on C2==C3 and SEAL C2. Byte-identity across generations depends
# on BYTE-IDENTICAL compile flags (identical DEFS + TCC_VERSION="0.9.27musl2" + ONE_SOURCE=1); tcc.c
# embeds no __DATE__/__TIME__ (verified), so compile_tcc() below fixes the flags for every generation.
mkdir -p /build/g/tm; cd /build/g/tm
tar --no-same-owner -xzf "$BUILDROOT/tccsrc.tar.gz" 2>/tmp/te || { gate_fail "extract tccsrc: $(head -1 /tmp/te)"; finish_fail; }
[ -d tccsrc ] || { gate_fail "no tccsrc dir (deterministic extract failure — fix the source, not a re-enqueue)"; finish_fail; }
cd "$BUILDROOT"
TCCSRC=/build/g/tm/tccsrc

# compile_tcc OUT CC LOG : compile tcc.c -> OUT with compiler CC, logging to LOG, run from INSIDE the
# tccsrc dir (uses -I .) after truncating config.h. Flags are FIXED here so C2 and C3 compile with
# BYTE-IDENTICAL invocations — any resulting sha difference is a real codegen divergence, not a flag
# artifact. Runs in a subshell so the caller's cwd is untouched; rc is the compile's rc.
compile_tcc(){
  local out="$1" cc="$2" log="$3"
  # HEADERS: -nostdinc + -I "$MI" reads ONLY the clean R4b musl sysroot — never the glibc-vs-musl coin-flip
  # /usr/include.  musl 1.1.24 ships its OWN stddef.h/stdarg.h/stdbool.h (verified), so -nostdinc is safe
  # (tcc-musl2 has no builtin-header dir anyway).  LINK: -nostdlib + explicit crt/libc from "$ML" links the
  # clean musl static libc (crt1 crti <tcc.c-obj> libc.a libtcc1.a libc.a crtn — libc.a twice so the
  # libtcc1<->libc back-refs resolve without --start-group, which tcc lacks).  This is R4b's PROVEN
  # float-gate invocation generalized to compile tcc.c.  The baked -D CONFIG_* values (SYSINCLUDEPATHS=
  # /usr/include etc.) are the emitted tcc's RUNTIME identity and stay UNCHANGED — R5 + the ecosystem
  # expect /usr/include at runtime; only s4's OWN compile flags move to the clean sysroot.  C2 and C3 share
  # this EXACT invocation, so any resulting sha divergence is a real codegen non-convergence, not a flag
  # artifact.
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

# --- Compile C2 (tcc-musl3) with C1 (tcc-musl2). A STABLE musl-linked compiler must NOT crash here.
compile_tcc "$TM3" "$TM2" /tmp/b3; bc=$?
if [ "$bc" != 0 ] || [ ! -x "$TM3" ]; then
  gate_fail "FIXPOINT compile C2 tcc.c->tcc-musl3 rc=$bc (a STABLE musl-linked compiler must NOT crash compiling tcc.c — tcc-musl2 is a bad mes-libc roll): $(tail -3 /tmp/b3 2>/dev/null | tr '\n' '|')"
  finish_fail
fi
"$TM3" -version >/tmp/v3 2>&1; r3=$?
[ "$r3" = 0 ] && emit "S4-FP-RUN tcc-musl3 -version rc=0 : $(head -1 /tmp/v3)" || gate_fail "FIXPOINT C2 tcc-musl3 -version rc=$r3 (self-compiled compiler does not run): $(head -1 /tmp/v3)"

# --- Compile C3 (tcc-musl4) with C2 (tcc-musl3). A fixed-point compiler MUST be able to compile tcc.c.
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

# GATE (fixed point): C2 must reproduce ITSELF bytewise. This is the trust-critical assertion.
if [ "$TM3SHA" = "$TM4SHA" ]; then
  emit "S4-FP-FIXPOINT PASS (C2==C3: tcc-musl3 reproduces itself bytewise — self-hosting fixed point reached; sealing C2)"
else
  gate_fail "FIXPOINT C2 != C3 (tcc-musl3 != tcc-musl4: the compiler does not converge — genuine wrong-but-running codegen defect, NOT the benign gen-0 mes-linked difference; hunt with the codegen oracle)"
fi

# Seal target is C2 (tcc-musl3's bytes), NOT C1. R5's `CC=tcc-musl2` musl-cc wrapper depends on the
# NAME tcc-musl2, but the CONTENT we bless is the fixed-point compiler C2.
SEALCC="$TM3"; SEALSHA="$TM3SHA"

# INFORMATIONAL (not gating): the gen-0 washout. C1 != C2 is the EXPECTED benign mes-linked residue;
# C1 == C2 just means gen-0 already converged. NEITHER is a failure — this must NOT call gate_fail.
if [ "$TM2SHA" = "$TM3SHA" ]; then
  emit "S4-FP-GEN0 C1==C2 (gen-0 already converged; C0's mes-linking left no libc-dependent codegen residue)"
else
  emit "S4-FP-GEN0 C1 != C2 (benign gen-0 mes-linked washout — informational, not a failure; see GATE 2 comment)"
fi

# ---- GATE 3 (+4 float): CODEGEN TORTURE SUITE ------------------------------------------------------
# Torture the SEALED fixed-point compiler C2 ($SEALCC = tcc-musl3), NOT the s3 input C1 — we validate
# exactly the bytes we are about to bless. Compile each torture test with C2 (-static, musl), RUN it,
# assert exit 0 AND stdout == the gcc-verified expected. This is the "ran but wrong" guard AND the
# regression suite for the amd64 codegen bugs we already found by RUNNING binaries. $(...) strips
# trailing newlines from BOTH sides (no diffutils needed; comparison is fair).
mkdir -p /build/g/tort; cd /build/g/tort
tar --no-same-owner -xzf "$BUILDROOT/torture.tar.gz" 2>/tmp/tte || { gate_fail "extract torture: $(head -1 /tmp/tte)"; finish_fail; }
[ -d torture ] || { gate_fail "no torture/ dir after extract"; finish_fail; }
TESTS="t_shift t_mul t_args t_varargs t_struct t_float t_longlong t_recursion t_bigframe t_switch t_setjmp"
pass=0; total=0
for t in $TESTS; do
  total=$((total+1))
  rm -f bin
  # Same clean-sysroot musl-cc invocation as compile_tcc: -nostdinc + explicit musl crt/libc, so the
  # torture gate exercises the sealed compiler against CLEAN musl and can never be tripped by glibc /usr.
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
# Cross-object (BUG1 static-PLT): a call to a DEFINED GLOBAL fn in a SEPARATE object — the exact defect
# that crashed -static links. Two units -> two .o -> one link -> run.
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

# Every gate passed -> graduate the fixed-point compiler C2 to the SEALED /usr/bin/tcc-musl2 +
# its gate-validated libtcc1.a + an explicit GATE-PASS marker.
mkdir -p "$BINOUT" "$LIBOUT"
# sealing C2 (tcc-musl3's bytes) as /usr/bin/tcc-musl2 — the fixed-point compiler under the name R5 expects.
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
  echo "      GATE 3 torture: $pass/$total RAN with correct output on the SEALED C2 (incl. static-PLT, varargs, longlong)."
  echo "      GATE 4 float: t_float strtod/printf-float correct against R4 musl."
  echo "      GATE 1 determinism (operator): assert S4-DETERM-INPUT-SHA == across >=2 fresh s3 rolls."
  echo "      GATE 5 provenance (manifest/orch): chain_enforce:true + overlay_active/retry_count in-toto."
  echo "      => tcc-musl2 is trust-grade; safe to seal in RemoteCache for R5 binutils."
} | tee "$MAN"
exit 0
