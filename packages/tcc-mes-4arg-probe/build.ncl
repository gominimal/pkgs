let { BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
# ─────────────────────────────────────────────────────────────────────────────────────────────
# tcc-mes-4arg-probe — a SINGLE-BUILD diagnostic that PINS WHICH C assert in tcc-mes's OWN
# x86_64 codegen (x86_64-gen.c) fires when the freshly-mescc-built amd64 tcc-mes compiles a
# C source containing a function call with >=4 arguments (the R2 frontier wall).
#
# THE BUG (probe-confirmed, deterministic 27/258 crash, min-prefix tip = lib/linux/execve.c):
# tcc-mes SIGSEGVs at COMPILE TIME on any TU emitting a >=4-arg call. The crash is a FALSE C
# assert inside tcc-mes's gfunc_call/classify codegen — mes-libc's assert() NULL-writes on a
# false condition (`assert fail: <#cond>` then a deliberate `fail[0]=0` -> SIGSEGV). mes assert
# DISCARDS file/line (`__assert_fail(#x,0,0,0)`), so the failing SITE cannot be read from the
# message -> we must INSTRUMENT. The earlier bisect saw `assert fail: 0`, which (nyacc stringizes
# the FULL #cond) means a LITERAL `assert(0)` fired — only x86_64-gen.c:1092 (classify default),
# :1313 (gfunc_call VT_LDOUBLE arm) and :2256 (gen_cvt_ftoi default) are literal assert(0). For
# execve.c's pure-4-integer-arg `_sys_call3(...)` call neither is reachable in CORRECT execution
# => the mescc-built tcc-mes is MISCOMPILED on gfunc_call's denser 4-arg path, corrupting a type
# value or counter so a literal assert(0) is reached. amd64 mes-tcc-0.9.26 is GENUINELY
# UNVALIDATED upstream (live-bootstrap ships only x86/riscv64 checksums).
#
# WHAT THIS PROBE DOES (STAGE-A only; no confident fix exists yet — see below):
#   * builds tcc-mes via R2's now-reliable no-growth-arena mescc path (MES_ARENA==MES_MAX_ARENA
#     =50M), BYTE-faithful to the production R2 binary EXCEPT for the assert instrumentation;
#   * BEFORE the `mescc tcc.c -> tcc.s` step, /usr/bin/simple-patch rewrites each bare assert in
#     x86_64-gen.c's gfunc_call/classify/gen_cvt_ftoi (12 sites) into
#         if (!(<cond>)) { write (2, "GFnnnn\n", 7); _exit (NN); }
#     where nnnn = the x86_64-gen.c line. write()=3-arg, _exit()=1-arg are mescc-SAFE (the bug is
#     >=4-arg only) and DECLARED for tcc.c via tcc.h's <unistd.h>/<stdlib.h> includes. This
#     REPLACES the buggy 4-arg __assert_fail call AND self-identifies the firing site by a
#     greppable stderr marker + a distinct exit code — no dependence on nyacc stringize;
#   * compiles lib/linux/execve.c (the minimal 4-arg repro) + fcntl.c/_read.c (other _sys_call3
#     4-arg crashers) and captures the GFnnnn marker -> PINNED_ASSERT; compiles access.c
#     (_sys_call2, 3-arg) as the must-stay-OK contrast.
#
# WHY NO STAGE-B FIX HERE: every synthesis dimension rates the EXACT mescc-miscompiled construct
# (vtop[-i] SValue index/struct-copy at i==3 vs a register-pressure counter clobber vs a
# switch mis-dispatch) at LOW/MEDIUM confidence and counsels AGAINST authoring a source "dodge"
# before the firing site (and ideally a value-dump) is pinned. So this build SPENDS its budget on
# a DECISIVE pin. STAGE-B is present-but-inert: build.sh runs a fix arm IFF /build/fix.before
# exists — ship a fix.before/fix.after Local pair in a follow-up to test a candidate dodge in the
# SAME 2-build budget once the assert is pinned.
#
# WHY NOT A KAEM RUNG: a diagnostic probe is not a trust rung, so it MAY use bash (build.sh,
# `set +e`) to tolerate the per-file compile-time SIGSEGV and ALWAYS exit 0 with an OutputData
# artifact + greppable rows. Mirrors mes-tcc-libc-bisect / mes-stability-sweep.
#
# PINNING: stage0-mes (R1) + stage0-mescc-full (R0.5) are imported WHOLE so mes-m2 / mescc.scm /
# the regenerated nyacc tables / mes-libc (libc+tcc.a) / headers / simple-patch are the EXACT
# binaries the failing R2 build uses, read in place at /usr. The tcc + mes Sources are the SAME
# sha-pinned tarballs R2 compiles. The two tcctools.c fopen patches R2 applies are DROPPED here:
# this probe only does `-c` compiles (never `-ar`), and gfunc_call codegen is wholly independent
# of tcctools.c — dropping them removes a failure surface without changing the instrumented binary.
let stage0-mes = import "../stage0-mes/build.ncl" in # R1: /usr/bin/{mes-m2,mescc.scm} + /usr/lib/x86_64-mes/** (incl libc+tcc.a) + /usr/include/** + /usr/share/{mes,nyacc}/module
let stage0-mescc-full = import "../stage0-mescc-full/build.ncl" in # R0.5: /usr/bin/simple-patch — the literal before->after substring patcher
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in # /usr/bin/bash — set +e, arrays, the conditional STAGE-B
let coreutils = import "../coreutils/build.ncl" in # /usr/bin/{cat,cp,chmod,mkdir,rm,wc,date,timeout,head,tail}
let grep = import "../grep/build.ncl" in # /usr/bin/grep — pull the GFnnnn marker out of stderr
{
  name = "tcc-mes-4arg-probe",
  build_deps = [
    { file = "build.sh" } | Local, # the bash harness (STAGE-A instrument+build+pin; optional STAGE-B fix arm)

    # ── instrumentation patch set (12 sites in x86_64-gen.c) ──────────────────────────────────
    # The THREE literal assert(0) share ONE before-pattern; simple-patch's first-match walks them
    # in source order 1092 -> 1313 -> 2256 (each .after contains no `assert(0);`), so the three
    # .after files (a/b/c) tag those three lines respectively. Verified byte-exact + ordering by
    # simulating the patch chain against the pinned tcc tarball.
    { file = "assert0.before" } | Local, # = `assert(0);`  (matches 1092,1313,2256)
    { file = "assert0-a.after" } | Local, # 1st walk -> :1092  GF1092 _exit(92)  (classify default)
    { file = "assert0-b.after" } | Local, # 2nd walk -> :1313  GF1313 _exit(13)  (gfunc_call VT_LDOUBLE)
    { file = "assert0-c.after" } | Local, # 3rd walk -> :2256  GF2256 _exit(56)  (gen_cvt_ftoi default)
    # the 9 readable gfunc_call asserts — each before-pattern is unique file-wide (grep-verified)
    { file = "gf-1318.before" } | Local,
    { file = "gf-1318.after" } | Local, # mode == sse
    { file = "gf-1334.before" } | Local,
    { file = "gf-1334.after" } | Local, # mode == integer
    { file = "gf-1355.before" } | Local,
    { file = "gf-1355.after" } | Local, # vtop/tmp type+r
    { file = "gf-1382.before" } | Local,
    { file = "gf-1382.after" } | Local, # mode == memory
    { file = "gf-1409.before" } | Local,
    { file = "gf-1409.after" } | Local, # gen_reg <= REGN
    { file = "gf-1410.before" } | Local,
    { file = "gf-1410.after" } | Local, # sse_reg <= 8
    { file = "gf-1428.before" } | Local,
    { file = "gf-1428.after" } | Local, # reg_count == 1
    { file = "gf-1450.before" } | Local,
    { file = "gf-1450.after" } | Local, # gen_reg == 0
    { file = "gf-1451.before" } | Local,
    { file = "gf-1451.after" } | Local, # sse_reg == 0
    {
      # janneke's lilypond tcc-0.9.26 fork — the SAME Source R2 compiles (byte-identical mirror,
      # sha preserved). Extracts to /build/tcc-0.9.26-1147-gee75a10c/ (= STAGE-A compile CWD).
      url = "gs://minimal-staging-archives/tcc-0.9.26-1147-gee75a10c.tar.gz",
      sha256 = "6b8cbd0a5fed0636d4f0f763a603247bc1935e206e1cc5bda6a2818bab6e819f",
      extract = true,
    } | Source,
    {
      # mes-0.27.1 SOURCE — supplies the crasher .c files (lib/linux/{execve,fcntl,_read,wait4}.c,
      # lib/stdio/snprintf.c) + the OK contrast (lib/linux/access.c) + the include/ tree. SAME
      # upstream sha as R1/R2's mes Source. Extracts to /build/mes-0.27.1/.
      url = "gs://minimal-staging-archives/mes-0.27.1.tar.gz",
      sha256 = "183a40ea47ea49f8a1e3bd1b9d12e676374d64d63bc79e7bc1ae7d673dfdf25d",
      extract = true,
    } | Source,
    stage0-mes, # R1 — mes-m2 + mescc.scm + mes-libc (libc+tcc.a) + headers + module trees
    stage0-mescc-full, # R0.5 — /usr/bin/simple-patch
    bash-bootstrap,
    coreutils,
    grep,
  ],
  # Explicit bash (do NOT rely on a shebang/interp). build.sh is a Local file placed at /build.
  cmds = [
    ["/usr/bin/bash", "build.sh"],
  ],
  outputs = {
    # The RESULT MATRIX. Also tee'd to stdout (lands in the debug-log bucket) so it is retrievable
    # even if the artifact capture is skipped. Harness ALWAYS exits 0 after emitting.
    matrix = { glob = "usr/share/tcc-mes-4arg-probe/matrix.txt" } | OutputData,
  },
} | BuildSpec
