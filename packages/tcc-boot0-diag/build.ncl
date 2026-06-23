let { BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
# ─────────────────────────────────────────────────────────────────────────────────────────────
# tcc-boot0-diag — a SINGLE-BUILD diagnostic for the NEXT amd64 mes-tcc wall. With the >=4-arg
# field-by-field swap fix (proven: full mes-libc compiles) AND the stdlib.h header-path fix (proven:
# tcc-boot0 COMPILES + links), R2 now dies at `tcc-boot0 -c crt1.c` — tcc-boot0 SIGSEGVs on its very
# FIRST use. tcc-boot0 = tcc.c compiled BY tcc-mes; it crashes on trivial input.
#
# KEY INSIGHT (from reading crt1.c): crt1.c's `_start` is almost ENTIRELY a GNU inline asm() block
# (AT&T x86_64: mov %rbp,%rax / syscall / REX regs). So `tcc-boot0 -c crt1.c` is the first thing that
# exercises tcc's INLINE ASSEMBLER (i386-asm.c, compiled in for TCC_TARGET_X86_64 per libtcc.c:67).
# tcc-mes compiled this SAME crt1.c fine during the libc build => tcc-boot0 (tcc-mes's OUTPUT) is a
# miscompiled tcc, and the breakage surfaces in the assembler subsystem.
#
# This probe ISOLATES where the crash lives, in ONE build (arena-saga lesson: diagnose, don't
# guess-and-rebuild). It builds the PATCHED tcc-mes (field-by-field swap), rebuilds mes-libc with it,
# builds tcc-boot0 (WITH the -I ${PREFIX}/include fix), then runs:
#   D1  tcc-boot0 -version                      -> rc. CRASH => tcc-boot0 broken at STARTUP.
#   D2a tcc-mes compiles+links+RUNS hello.c     -> rc==42? tcc-mes CODEGEN+libc.a on simple C.
#   D2b tcc-mes compiles+links+RUNS const4arg.c -> rc==55? the >=4-arg / 16-byte CValue-union swap.
#   D2c tcc-mes compiles+links+RUNS asmtest.c   -> rc==7?  tcc-mes's INLINE-ASM path (mov/add asm).
#   D3a tcc-boot0 compiles+links+RUNS hello.c   -> rc==42? (if D1 ok) tcc-boot0 codegen on NON-asm C.
#   D3b tcc-boot0 compiles+links+RUNS asmtest.c -> rc==7?  tcc-boot0's INLINE-ASM path (THE suspect).
#   D4  tcc-boot0 -c crt1.c                      -> reproduce the real R2 crash + capture stderr.
#   D5  tcc-mes -S asmtest.c / const4arg.c       -> dump the asm-path + >=4-arg call-site asm.
#
# VERDICT LOGIC (printed in MANIFEST):
#   D3a OK + D3b CRASH        => the miscompiled subsystem is the INLINE ASSEMBLER (i386-asm.c) in
#                               tcc-boot0 -> focus the fix there (a construct tcc-mes mis-emits).
#   D2c OK + D3b CRASH        => tcc-mes's own asm path is fine but the COPY it generated (tcc-boot0)
#                               is broken -> a codegen bug in how tcc-mes compiled i386-asm.c.
#   D2a OK + D2b FAIL         => the >=4-arg / c-union copy corrupts CONSTANT args -> refine swap `.c`.
#   D2a FAIL                  => tcc-mes codegen/libc.a broken on simple C -> deeper.
#   D1 CRASH but D3a unreached=> tcc-boot0 broken at startup (libc.a/crt it links).
#
# Diagnostic probe, not a trust rung: build.sh uses bash + `set +e`, never aborts, ALWAYS exits 0 with
# greppable rows + OutputData. Pins (mes-m2/mescc/mes-libc/headers/simple-patch + the tcc & mes
# Sources) are the EXACT binaries/tarballs the failing R2 uses, so the diagnosis is faithful.
let stage0-mes = import "../stage0-mes/build.ncl" in # R1: mes-m2 + mescc.scm + mes-libc + headers
let stage0-mescc-full = import "../stage0-mescc-full/build.ncl" in # R0.5: /usr/bin/simple-patch
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in # /usr/bin/bash — set +e, the battery
let coreutils = import "../coreutils/build.ncl" in # cp/chmod/mkdir/rm/wc/cat/head/tail/uname/timeout
let grep = import "../grep/build.ncl" in # greppable-row extraction
let gawk = import "../gawk/build.ncl" in # asm slice (column-0 label walk)
let gzip = import "../gzip/build.ncl" in # compress the dumped asm
{
  name = "tcc-boot0-diag",
  build_deps = [
    { file = "build.sh" } | Local,
    # tcctools.c fopen relocation — so tcc-mes/tcc-boot0 `-ar` works (mes-libc fopen ordering); == R2.
    { file = "remove-fileopen.before" } | Local,
    { file = "remove-fileopen.after" } | Local,
    { file = "addback-fileopen.before" } | Local,
    { file = "addback-fileopen.after" } | Local,
    # FIX#2: field-by-field SValue swap (byte-identical to stage0-tcc-0.9.26's fix-swapf/fix-swapb).
    { file = "fix-swapf.before" } | Local,
    { file = "fix-swapf.after" } | Local,
    { file = "fix-swapb.before" } | Local,
    { file = "fix-swapb.after" } | Local,
    {
      # janneke's tcc-0.9.26 fork — the SAME Source R2 compiles. Extracts to /build/<TCC_PKG>/.
      url = "gs://minimal-staging-archives/tcc-0.9.26-1147-gee75a10c.tar.gz",
      sha256 = "6b8cbd0a5fed0636d4f0f763a603247bc1935e206e1cc5bda6a2818bab6e819f",
      extract = true,
    } | Source,
    {
      # mes-0.27.1 SOURCE — mes-libc lib/** + include/ tree. SAME sha as R1/R2.
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
  ],
  cmds = [
    ["/usr/bin/bash", "build.sh"],
  ],
  outputs = {
    manifest = { glob = "usr/share/tcc-boot0-diag/MANIFEST.txt" } | OutputData,
    logs = { glob = "usr/share/tcc-boot0-diag/*.log" } | OutputData,
    asm = { glob = "usr/share/tcc-boot0-diag/*.s" } | OutputData,
    gz = { glob = "usr/share/tcc-boot0-diag/*.gz" } | OutputData,
    binaries = { glob = "usr/share/tcc-boot0-diag/tcc-*" } | OutputData,
  },
} | BuildSpec
