let { BuildSpec, Local, OutputBin, OutputLib, OutputData, .. } = import "minimal.ncl" in
# DRAFT 2026-06-30 — operator review before wiring (spec: .staging-ctx/correctness-gate-2026-06-30.md).
# R4a STAGE 4 — THE CORRECTNESS GATE.  s3 produces tcc-musl2 (musl-linked), but the s1/s3 mes-libc
# compile that BIRTHED it crashes ~95% and may ~5% of the time emit a WRONG-BUT-RUNNING tcc-musl2.
# A seal gated only on "did it run / -version / hello.c" is NOT trust-grade — it cannot catch
# "ran but wrong."  s4 is the mechanism-INDEPENDENT trust capstone that MUST pass before tcc-musl2
# is sealed in RemoteCache.  It does NOT roll the lottery (tcc-musl2 is stable/musl-linked); a
# failure here is DETERMINISTIC and means the s3 tcc-musl2 INPUT is bad -> re-roll s3, do NOT retry s4.
#
# THE GATES (all must pass; the build emits NO sealed binary unless every gate passes):
#   1. DETERMINISM  — s4 records sha256(tcc-musl2) it consumed (S4-DETERM-INPUT-SHA). Operator compares
#                     this across >=2 fresh-sandbox s3 rolls; must be byte-identical. (cross-build, op-driven)
#   2. FIXED POINT  — tcc-musl2 recompiles tcc.c -> tcc-musl3 (s3's EXACT invocation, same TCC_VERSION),
#                     assert tcc-musl3 RUNS (-version rc=0) AND sha256(tcc-musl3)==sha256(tcc-musl2)
#                     bytewise.  The self-hosting wash live-bootstrap does (pass2) that we never have.
#   3. TORTURE      — compile each torture test with tcc-musl2 (-static, musl), RUN it, assert exit 0
#                     AND stdout == the gcc-verified expected output.  Catches "ran but wrong."  Covers
#                     the amd64 bug classes we found the hard way: static-PLT cross-object calls (BUG1),
#                     strength-reduction multiply (BUG2), constant shift-count (fix-shift), >=4/6/7-arg
#                     register+stack passing (lb#470), varargs/va_list, struct-by-value, long-long
#                     (__udivdi3 libtcc1.a helper), recursion, large frames, switch, setjmp.
#   4. MUSL FLOAT   — t_float exercises tcc float codegen + musl strtod/printf-float (we collapsed
#                     live-bootstrap's tcc<->musl float-fix interleave; a buggy-float libc would
#                     masquerade as "amd64 tcc codegen").  All values are exact binary => libc-invariant.
#   5. PROVENANCE   — declared OUT-OF-BAND: chain_enforce:true in manifest.json + overlay_active/
#                     retry_count in in-toto (see the s4 manifest + the orch note); not a build.sh gate.
#
# Clean MUSL env: deps R4b (musl: libc.a + crt + headers) + s3 (tcc-musl2 + libtcc1.a) ONLY — no R1,
# so /usr/include is pure musl, exactly like s3.  NOT trust-grade until built from the vendored image
# with overlay cleared.  See [[bedrock-spine-retrospective-2026-06-30]] §5 (correctness_gate_design).
# LINK TARGET REWIRED 2026-07-01: the musl this gate links against (t_float + the fixed-point tcc.c
# compiles: /usr/lib/{libc.a,crt*.o} + /usr/include) now comes from R4b (stage0-musl-1.1.24-cc2, the
# DETERMINISTIC tcc-musl2-built musl), NOT the lottery-prone R4a.  R4b is correct-by-construction (no
# float corruption), so the gate stops linking against a possibly-corrupt R4a libc.  No cycle: s4→R4b→s3
# and s4→s3→s1→R4a all point toward the seed (R4b is a rung ABOVE R4a, not a replacement for it).
let stage0-musl-r4b = import "../stage0-musl-1.1.24-cc2/build.ncl" in         # R4b — DETERMINISTIC musl libc.a + crt + headers (link target)
let stage0-tcc-musl-s3 = import "../stage0-tcc-0.9.27-musl-s3/build.ncl" in   # tcc-musl2 (candidate) + libtcc1.a
let bash = import "../bash/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let tar = import "../tar/build.ncl" in
let gzip = import "../gzip/build.ncl" in
let sed = import "../sed/build.ncl" in
let grep = import "../grep/build.ncl" in
let gawk-bootstrap = import "../gawk-bootstrap/build.ncl" in
{
  name = "stage0-tcc-0.9.27-musl-s4",
  build_deps = [
    { file = "build.sh" } | Local,
    { file = "tccsrc.tar.gz" } | Local,    # IDENTICAL to s3's source (GOT fixes A,B,C) — the fixed-point recompile MUST use the same tcc.c
    { file = "torture.tar.gz" } | Local,   # torture/*.c + *.expected (expected stdout verified against gcc at authoring time)
    stage0-musl-r4b,
    stage0-tcc-musl-s3,
    bash,
    coreutils,
    tar,
    gzip,
    sed,
    grep,
    gawk-bootstrap,
  ],
  cmd = "./build.sh",
  outputs = {
    # THE SEAL TARGET. This binary is a byte-identical copy of tcc-musl2 that PHYSICALLY CANNOT EXIST
    # unless every gate passed (build.sh cp's it only after GATEFAIL==0). On any gate failure the build
    # exits 1 AND leaves this absent -> the OutputBin glob matches nothing -> minimal marks the build
    # FAILED -> nothing is sealed/cached/published. Double-gated: explicit exit 1 + absent artifact.
    # Downstream R5 binutils imports s4 and uses /usr/bin/tcc-musl2 as CC — the gate is unbypassable.
    tcc = { glob = "usr/bin/tcc-musl2", allow_missing_interpreter = true } | OutputBin,
    libtcc1 = { glob = "usr/lib/tcc/libtcc1.a" } | OutputLib,   # gate-validated (torture exercises __udivdi3/__va_start)
    gatepass = { glob = "usr/share/tcc-musl-s4/GATE-PASS" } | OutputData,   # only written on full pass
    manifest = { glob = "usr/share/tcc-musl-s4/MANIFEST.txt" } | OutputData,
    logs = { glob = "usr/share/tcc-musl-s4/rows.log" } | OutputData,
  },
} | BuildSpec
