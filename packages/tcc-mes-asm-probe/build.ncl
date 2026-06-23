let { BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
# ─────────────────────────────────────────────────────────────────────────────────────────────
# tcc-mes-asm-probe — a SINGLE-BUILD probe that BOTH (A) captures ground-truth and (B) tests the
# next fix for the amd64 mes-tcc >=4-arg-call SIGSEGV (mescc miscompiles tcc-mes's gfunc_call; the
# 4th integer arg's type.t is corrupted -> x86_64-gen.c:1318 assert(mode==x86_64_mode_sse) fires at
# COMPILE TIME). FIX#1 (cache vtop-i into a local SValue* at the 5 vtop[-i] sites; committed gf-*
# in stage0-tcc-0.9.26, commit 09a5824) did NOT help — so the negative-index ADDRESSING is ruled
# out and the remaining suspect is the 42-byte SValue STRUCT-COPY in the swap.
#
# (A) CAPTURE — build the CANONICAL tcc-mes via R2's no-growth-arena (MES_ARENA==MES_MAX_ARENA=50M)
#     mescc path with the FULL R2 -D argv, and capture as retrievable OutputData:
#       * the mescc-EMITTED asm (tcc.s, M1/stage0 syntax) sliced for gfunc_call AND
#         classify_x86_64_arg (+inner/merge/gfunc_prolog),
#       * the FULL tcc.s gzipped (~123k lines),
#       * the linked tcc-mes binary (static ELF, for local `objdump -d`).
#     Plus run {execve,fcntl,wait4,snprintf}.c to PIN the canonical CRASH baseline.
# (B) FIX#2 — reset x86_64-gen.c to pristine, apply the FIELD-BY-FIELD SValue swap (fix-swapf +
#     fix-swapb: the two whole-struct swaps in gfunc_call's run loop become per-field copies — the
#     CValue union is copied as one clean 16-byte assignment, the rest as scalar stores, so mescc
#     never takes its 42-byte chunked mem->mem struct-copy loop or its mod-8 tail), rebuild tcc-mes,
#     recompile the 4 crashers -> PASS/CRASH per file, and DIFF the patched gfunc_call asm vs
#     canonical. The matrix + diff are the verdict on whether the struct-copy is the bug.
#
# HOW gfunc_call IS LOCATED IN tcc.s: mescc/M1 emits each C function as a COLUMN-0 label `:<name>`
# (M1.scm:278) and every in-function local label as `:_<name>_<n>_...` (compile.scm:1110). The PE
# gfunc_call def (source:784) is #ifdef'd out (we set TCC_TARGET_X86_64, not TCC_TARGET_PE), so only
# the SysV #else def (~1195) reaches mescc -> `:gfunc_call` is unambiguous. build.sh slice_fn() walks
# from `:gfunc_call` through all `:_gfunc_call_*` locals, stopping at the next other column-0 label.
#
# fix-swapf.before / fix-swapb.before are BYTE-IDENTICAL copies of stage0-tcc-0.9.26/gf-swapf.before
# and gf-swapb.before — each verified to occur EXACTLY ONCE in the pinned pristine x86_64-gen.c (the
# PE gfunc_call uses a different `sv = &vtop[-i]` idiom), so simple-patch's first-match lands on the
# active SysV swap.
#
# WHY NOT A KAEM RUNG: a diagnostic probe is not a trust rung, so it MAY use bash (build.sh,
# `set +e`) to tolerate sub-step failure and ALWAYS exit 0 with OutputData + greppable rows.
# Mirrors mes-tcc-libc-bisect / tcc-mes-4arg-probe / mes-gfunc-asm-capture.
#
# PINNING: stage0-mes (R1) + stage0-mescc-full (R0.5) imported WHOLE so mes-m2 / mescc.scm / the
# regenerated nyacc tables / mes-libc (libc+tcc.a) / headers / simple-patch are the EXACT binaries
# the failing R2 build uses (read in place at /usr). The tcc + mes Sources are the SAME sha-pinned
# tarballs R2 compiles. The tcctools.c fopen patches are verbatim from stage0-tcc-0.9.26 so the
# captured binary is byte-faithful to the production R2 tcc-mes.
let stage0-mes = import "../stage0-mes/build.ncl" in # R1: mes-m2 + mescc.scm + mes-libc (libc+tcc.a) + headers + module trees
let stage0-mescc-full = import "../stage0-mescc-full/build.ncl" in # R0.5: /usr/bin/simple-patch
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in # /usr/bin/bash — set +e, arrays, the two-phase loop
let coreutils = import "../coreutils/build.ncl" in # /usr/bin/{cp,chmod,mkdir,rm,wc,cat,head,tail,uname,timeout}
let grep = import "../grep/build.ncl" in # /usr/bin/grep — classify + labels-and-moves extract
let gawk = import "../gawk/build.ncl" in # /usr/bin/awk — slice_fn() (column-0 label walk)
let gzip = import "../gzip/build.ncl" in # /usr/bin/gzip — compress the ~123k-line full tcc.s
let diffutils = import "../diffutils/build.ncl" in # /usr/bin/diff — canonical-vs-patched gfunc_call diff
{
  name = "tcc-mes-asm-probe",
  build_deps = [
    { file = "build.sh" } | Local, # the bash harness (PHASE A capture + PHASE B FIX#2 + matrix + diff)
    # tcctools.c fopen relocation — applied so the linked binary == the R2 binary (ONE_SOURCE=1).
    { file = "remove-fileopen.before" } | Local,
    { file = "remove-fileopen.after" } | Local,
    { file = "addback-fileopen.before" } | Local,
    { file = "addback-fileopen.after" } | Local,
    # FIX#2: field-by-field SValue swap. *.before are byte-identical to stage0-tcc-0.9.26's
    # gf-swapf.before / gf-swapb.before (each occurs exactly once in pristine x86_64-gen.c).
    { file = "fix-swapf.before" } | Local,
    { file = "fix-swapf.after" } | Local,
    { file = "fix-swapb.before" } | Local,
    { file = "fix-swapb.after" } | Local,
    {
      # janneke's lilypond tcc-0.9.26 fork — the SAME Source R2 compiles (sha preserved).
      # Extracts to /build/tcc-0.9.26-1147-gee75a10c/ (= the mescc compile CWD).
      url = "gs://minimal-staging-archives/tcc-0.9.26-1147-gee75a10c.tar.gz",
      sha256 = "6b8cbd0a5fed0636d4f0f763a603247bc1935e206e1cc5bda6a2818bab6e819f",
      extract = true,
    } | Source,
    {
      # mes-0.27.1 SOURCE — supplies mes-libc lib/** (tcc.c links it via -l c+tcc) + include/ tree,
      # and the {execve,fcntl,wait4,snprintf}.c crashers PHASE-B recompiles. SAME sha as R1/R2.
      url = "gs://minimal-staging-archives/mes-0.27.1.tar.gz",
      sha256 = "183a40ea47ea49f8a1e3bd1b9d12e676374d64d63bc79e7bc1ae7d673dfdf25d",
      extract = true,
    } | Source,
    stage0-mes,
    stage0-mescc-full,
    bash-bootstrap,
    coreutils,
    grep,
    gawk,
    gzip,
    diffutils,
  ],
  cmds = [
    ["/usr/bin/bash", "build.sh"],
  ],
  outputs = {
    # MANIFEST + RESULT MATRIX (also tee'd to stdout -> debug-log bucket, retrievable even on skip).
    manifest = { glob = "usr/share/tcc-mes-asm-probe/MANIFEST.txt" } | OutputData,
    # per-function emitted-asm slices (both phases): gfunc_call*.s, classify_x86_64_*.s, gfunc_prolog*.s
    slices = { glob = "usr/share/tcc-mes-asm-probe/*.s" } | OutputData,
    # canonical-vs-patched diffs (gfunc_call + classify_x86_64_arg/inner)
    diffs = { glob = "usr/share/tcc-mes-asm-probe/*.diff" } | OutputData,
    # labels+moves convenience extracts
    moves = { glob = "usr/share/tcc-mes-asm-probe/*.labels-and-moves.txt" } | OutputData,
    # full emitted asm, gzipped (~123k lines raw): tcc.s.canonical.gz + tcc.s.patched.gz
    full_asm = { glob = "usr/share/tcc-mes-asm-probe/tcc.s.*.gz" } | OutputData,
    # the linked tcc-mes binaries for local `objdump -d` (static ELF): tcc-mes.canonical + tcc-mes.patched
    binaries = { glob = "usr/share/tcc-mes-asm-probe/tcc-mes.*" } | OutputData,
  },
} | BuildSpec
