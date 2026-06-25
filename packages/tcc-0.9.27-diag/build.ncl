let { BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
# ─────────────────────────────────────────────────────────────────────────────────────────────
# tcc-0.9.27-diag — a SINGLE-BUILD diagnostic for the R3 wall. R3 (stage0-tcc-0.9.27) fails because
# tcc-0.9.26 (the SEALED R2 deliverable, a correct compiler) SIGSEGVs (GP-fault ip:0x448b80, ≈ the
# strlen/error-formatting path) compiling tcc-0.9.27's tcc.c — at `-> tcc.c`, masked (tcc crashes
# FORMATTING the error). i386 compiles tcc-0.9.27 fine, so the source is clean → this is a LATENT
# tcc-0.9.26 *amd64-codegen* (or amd64 error-varargs) bug that tcc-0.9.27's constructs trigger but
# tcc-0.9.26's own tcc.c never did. -w did NOT fix it (so it's an ERROR/codegen crash, not a warning).
#
# This probe UNMASKS the crash in ONE build (arena-saga lesson: diagnose, don't guess-and-rebuild).
# It applies R3's exact patches to tcc-0.9.27, then runs `tcc-0.9.26 -c tcc.c` THREE ways:
#   (1) -vv  — capture the last verbose action before the crash (which file/phase).
#   (2) under a ptrace TRACER (the proven tcc-boot0-diag harness, adapted: CONT→waitpid catches the
#       SIGSEGV EXACTLY, since R3 crashes rather than hangs) — prints rip + the rbp-chain backtrace.
#   (3) saves tcc-0.9.26 (UNSTRIPPED, built with -g) to the output so the backtrace addresses map to
#       function names via local `objdump` (the binary is the R2 deliverable, available via R2 dep).
# Reusable template for R6 (tcc → gcc-4.0.4), the same bug-class on a bigger source.
#
# Diagnostic probe, not a trust rung: build.sh uses bash + `set +e`, never aborts, ALWAYS exits 0 with
# greppable rows + OutputData. Pins are the EXACT binaries/tarball R3 uses, so the diagnosis is faithful.
let stage0-tcc-r2 = import "../stage0-tcc-0.9.26/build.ncl" in # R2: the SEALED tcc-0.9.26 + its /usr/lib/mes libc (the compiler under test)
let stage0-mes = import "../stage0-mes/build.ncl" in # R1: /usr/include mes-libc headers (tcc.c's <stdlib.h> etc.)
let stage0-mescc-full = import "../stage0-mescc-full/build.ncl" in # R0.5: /usr/bin/{simple-patch,catm}
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in # /usr/bin/bash — set +e probe driver
let coreutils = import "../coreutils/build.ncl" in # cp/chmod/mkdir/rm/wc/cat/head/tail/uname/timeout
let grep = import "../grep/build.ncl" in # greppable-row extraction
{
  name = "tcc-0.9.27-diag",
  build_deps = [
    { file = "build.sh" } | Local,
    # R3's exact tcc-0.9.27 source patches (byte-identical to stage0-tcc-0.9.27/) — applied before the
    # tcc.c compile so the crash reproduces FAITHFULLY (these are part of tcc-0.9.27's ONE_SOURCE).
    { file = "remove-fileopen.before" } | Local,
    { file = "remove-fileopen.after" } | Local,
    { file = "addback-fileopen.before" } | Local,
    { file = "addback-fileopen.after" } | Local,
    { file = "fiwix-paddr.before" } | Local,
    { file = "fiwix-paddr.after" } | Local,
    { file = "check-reloc-null.before" } | Local,
    { file = "check-reloc-null.after" } | Local,
    {
      # mainline tcc-0.9.27 — the SAME Source R3 compiles. Extracts to /build/tcc-0.9.27/.
      url = "gs://minimal-staging-archives/tcc-0.9.27.tar.bz2",
      sha256 = "de23af78fca90ce32dff2dd45b3432b2334740bb9bb7b05bf60fdbfc396ceb9c",
      extract = true,
    } | Source,
    stage0-tcc-r2,
    stage0-mes,
    stage0-mescc-full,
    bash-bootstrap,
    coreutils,
    grep,
  ],
  cmds = [
    ["/usr/bin/bash", "build.sh"],
  ],
  # every OutputData glob MUST match >=1 file or minimal marks the build FAILED. All guaranteed on a
  # full run: MANIFEST.txt + copied *.log + the saved tcc-0.9.26 binary (tcc-*).
  outputs = {
    manifest = { glob = "usr/share/tcc-0.9.27-diag/MANIFEST.txt" } | OutputData,
    logs = { glob = "usr/share/tcc-0.9.27-diag/*.log" } | OutputData,
    binaries = { glob = "usr/share/tcc-0.9.27-diag/tcc-*" } | OutputData,
  },
} | BuildSpec
