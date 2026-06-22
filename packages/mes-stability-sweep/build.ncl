let { BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
# ─────────────────────────────────────────────────────────────────────────────────────────────
# mes-stability-sweep — a SINGLE-BUILD diagnostic that sweeps many mes-m2 arena/stack/ulimit
# configs over the EXACT R2 mescc tcc.c->tcc.s compile, repeating each N=3 to expose ASLR /
# run-to-run flakiness, capturing per-run outcome (PASS / PARSEFAIL / SIGSEGV / SIGABRT /
# TIMEOUT) + timing WITHOUT aborting on a per-config crash. One ~30-45min rebuild yields a
# whole RESULT MATRIX instead of the one data point a kaem rung gives.
#
# WHY THIS IS NOT A KAEM RUNG: kaem --strict aborts HARD on the first non-zero child, so a kaem
# sweep stops at the first crash. A diagnostic probe is NOT a trust rung, so it may use bash
# (build.sh) which can `set +e` (tolerate per-config crashes) AND `ulimit -s` (kaem cannot).
# This mirrors ia32-probe: a non-trust probe that produces an OutputData artifact and exits 0.
#
# THE BUG (R2 "wall"): mes-m2 (M2-Planet-built mes 0.27.1) is UNSTABLE / NON-DETERMINISTIC
# compiling tcc.c. 3 builds, 3 outcomes: (A) 30M/30M no-growth -> SUCCESS; (B) same 30M/30M,
# different image -> parse-fail "state 410 on size_t" @10s; (C) 100M/300M growth -> SIGSEGV @32s.
# Bigger arena crashed EARLIER => arena size is not a clean lever; outcome is memory-layout-
# dependent (each NOCACHE rebuild reshuffles layout, so A/B/C are confounded, not a controlled
# sweep). Under guile the SAME mescc+nyacc compiles all of tcc.c fine -> mes-m2-runtime-specific.
#
# WHAT THE SWEEP CONTROLS (within ONE image / one R1 output, so no image-drift confound):
#   - MES_ARENA == MES_MAX_ARENA (NO growth: gc_up_arena never fires) vs MES_ARENA < MES_MAX_ARENA
#     (growth ON: arms gc_up_arena's realloc + pointer-relocating memcpy — the prime suspect).
#   - MES_ARENA size ladder, all kept SAFELY under the 32-bit overflow ceiling (see below).
#   - MES_STACK (mes VM cell-stack, lives inside the arena malloc — orthogonal to OS C stack).
#   - OS `ulimit -s` (the C call stack — the one lever upstream never sets) to falsify C-stack
#     overflow: eval_apply is a goto-trampoline, so we predict NO effect.
#   - ASLR on vs off (setarch -R / personality(ADDR_NO_RANDOMIZE)) to test layout-dependence.
#
# 32-bit OVERFLOW CEILING (the load-bearing safety bound): under M2-Planet `size_t` is 32-bit
# `unsigned` (include/mes/lib-mini.h:74-75 `#if __M2__ typedef unsigned size_t`). ARENA_SIZE /
# MAX_ARENA_SIZE / JAM_SIZE / STACK_SIZE are all `size_t`, so the byte math
# (ARENA_SIZE + JAM_SIZE) * sizeof(struct scm)  [cell = 24B, JAM = ARENA/10]  is a 32-BIT
# multiply that wraps at 2^32. It overflows once ARENA exceeds ~162.7M cells; adding STACK lowers
# the safe ceiling. The harness therefore (a) keeps every NO-GROWTH ARENA well under ~150M, (b)
# enforces a budget guard (ARENA*1.1 + STACK)*24 < ~3.8e9 before each run (prints SKIPPED-OVERFLOW
# rather than crash confusingly), and (c) DELIBERATELY exercises the growth-doubling overflow only
# in the two diagnostic growth rows. All values are RAM-safe on the 122GB builder.
#
# PINNING: stage0-mes (R1) is imported WHOLE so mes-m2 / mescc.scm / the regenerated nyacc c99
# tables / mes module trees / headers are the EXACT binaries the failing R2 builds use, read in
# place at /usr — this is what makes the sweep a controlled arena/stack study (the case-B
# cross-image confound is held fixed; a clean sweep does NOT clear the cross-IMAGE drift axis,
# which only separate builds can probe).
let stage0-mes = import "../stage0-mes/build.ncl" in # R1: /usr/bin/{mes-m2,mescc.scm} + /usr/include/** + /usr/share/{mes,nyacc}/module
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in # /usr/bin/bash — set +e, arrays, ulimit -s
let coreutils = import "../coreutils/build.ncl" in # /usr/bin/{date,timeout,wc,cp,mkdir,rm,chmod,cat}
let util-linux = import "../util-linux/build.ncl" in # /usr/bin/setarch — the ASLR-off (-R) rows
let grep = import "../grep/build.ncl" in # /usr/bin/grep — classify() buckets runs by stderr signature
{
  name = "mes-stability-sweep",
  build_deps = [
    { file = "build.sh" } | Local, # the bash sweep harness (set +e; per-config ulimit/env; loops the matrix)
    {
      # janneke's lilypond tcc-0.9.26 fork — the SAME Source R2 compiles (byte-identical mirror,
      # sha preserved). Extracts to /build/tcc-0.9.26-1147-gee75a10c/ (= the compile CWD).
      url = "gs://minimal-staging-archives/tcc-0.9.26-1147-gee75a10c.tar.gz",
      sha256 = "6b8cbd0a5fed0636d4f0f763a603247bc1935e206e1cc5bda6a2818bab6e819f",
      extract = true,
    } | Source,
    stage0-mes, # R1 — mes-m2 + mescc.scm + nyacc/mes modules + headers (read in place at /usr)
    bash-bootstrap,
    coreutils,
    util-linux, # setarch for the ASLR-off rows (tolerated-absent: harness probes it first)
    grep, # classify() greps stderr for STACK FULL / out of memory / parse failed / up[ growth marker
  ],
  # Explicit bash (do not rely on a shebang/interp). build.sh is a Local file placed at /build.
  cmds = [
    ["/usr/bin/bash", "build.sh"],
  ],
  outputs = {
    # The RESULT MATRIX. Also echoed to stdout (lands in the debug-log bucket) so it is
    # retrievable even if the artifact capture is skipped. Harness ALWAYS exits 0 after emitting.
    matrix = { glob = "usr/share/mes-stability-sweep/matrix.txt" } | OutputData,
  },
} | BuildSpec
