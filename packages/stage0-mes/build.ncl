let { BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let stage0-mescc-full = import "../stage0-mescc-full/build.ncl" in # R0.5: SOLE toolchain supplier — final M2-Planet + re-exported kaem/catm/M1/hex2/blood-elf
let coreutils = import "../coreutils/build.ncl" in
let tar = import "../tar/build.ncl" in
let gzip = import "../gzip/build.ncl" in
let sed = import "../sed/build.ncl" in
# R1 — stage0-mes.  GNU Mes 0.27.1: the first from-source C-with-libc step.  M2-Planet
# (from R0, stage0-mescc) compiles mes-m2 (a subset-C port of the Mes Scheme interpreter);
# mes-m2 then runs MesCC (mescc.scm) to (re)build mes-libc (crt1.o, libc.a, libc+tcc.a,
# libmescc.a) and regenerate nyacc's pregenerated parser tables.  The deliverable is the
# mes-m2 binary + mescc.scm + the mes-libc tree that R2 (tcc-0.9.26) compiles/links against.
#
# DRIVER = the ATTESTED full C kaem from R0 (/usr/bin/kaem, 6364de59…).  NOT bash (B1.5
# retired bash), NOT a flat cmds-argv vector (mes needs control flow / vars / cd / alias /
# an inner `kaem --file`, all beyond cmds-argv).  This is exactly what live-bootstrap uses
# to run steps/mes-0.27.1/pass1.kaem; mes.kaem is a faithful port of that script.  kaem
# aborts HARD on any non-zero child, so `sha256sum -c mes.answers` is a build-failing gate.
#
# Trust spine: build_dep stage0-mescc makes R0 a genuine predecessor (recursive signer walk
# reaches R0 -> stage0-kaem -> hex0/hex1 -> the 229-byte seed).  The file/unpack/patch
# utilities are the ATTESTED base tools (coreutils/tar/gzip/sed) — the Model B posture
# (B3-mes-gcc-climb.md §0): rebuild only the compiler spine from source, drive with attested
# base.  catm comes from R0 (it is genuinely needed; kaem has no shell redirection).
{
  name = "stage0-mes",
  build_deps = [
    { file = "mes.kaem" } | Local, # full-kaem-driven port of live-bootstrap pass1.kaem
    { file = "mes.answers" } | Local, # sha256sum -c byte-identity gate (13 upstream pins)
    { file = "config.h" } | Local, # live-bootstrap files/config.h (SYSTEM_LIBC undef + MES_VERSION)
    {
      # UPSTREAM: GNU Mes 0.27.1.  sha is the upstream-published value (live-bootstrap
      # steps/mes-0.27.1/sources); mirroring to the staging bucket preserves it.
      url = "gs://minimal-staging-archives/mes-0.27.1.tar.gz",
      sha256 = "183a40ea47ea49f8a1e3bd1b9d12e676374d64d63bc79e7bc1ae7d673dfdf25d",
      extract = true,
    } | Source,
    {
      # nyacc 1.00.2-lb1 (the live-bootstrap fork release; ships the Scheme C99 parser
      # that MesCC uses).  Extracts to a top-level dir — confirm name at build (see
      # mes.kaem NYACC_DIR; expected nyacc-1.00.2, possibly nyacc-1.00.2-lb1).
      url = "gs://minimal-staging-archives/nyacc-1.00.2-lb1.tar.gz",
      sha256 = "708c943f89c972910e9544ee077771acbd0a2c0fc6d33496fe158264ddb65327",
      extract = true,
    } | Source,
    {
      # Reused S0 tarball (same sha as stage0-hex1/stage0-kaem/stage0-mescc) — supplies the
      # M2libc tree that the inner `kaem --file kaem.x86_64` build of mes-m2 needs
      # (M2LIBC_PATH).  mes 0.27.1 does NOT ship M2libc; live-bootstrap points at stage0's.
      url = "gs://minimal-staging-archives/stage0-posix-1.9.1.tar.zst",
      sha256 = "33108c8c1271a12c3eae9509dff4c10c55b7475548cf5d370778eaf7138194df",
      extract = true,
    } | Source,
    # The from-source mescc toolchain (matching the sibling R2 draft's import convention).
    # CRITICAL: live-bootstrap builds mes-m2 with the FINAL self-hosted bin/M2-Planet
    # (seed.kaem copies bin/M2-Planet), NOT the bootstrap artifact/M2.  Per R0's draft the
    # final bin/M2-Planet lives in R0.5 (stage0-mescc-full); R0 (mini) only emits artifact/M2.
    stage0-mescc-full, # R0.5 (SOLE toolchain supplier): /usr/bin/{M2-Planet(final),kaem(=driver),catm,M1,hex2,blood-elf,M2-Mesoplanet,match,simple-patch,get_machine}. NOT stage0-mescc (R0) directly — R0 reached transitively via R0.5; the subsetOf selective-import alt panics the spec-hasher (CONTRACTS.md §A).
    coreutils, # /usr/bin/{mkdir,cp,rm,chmod,sha256sum}
    tar, # /usr/bin/tar   (untar replacement)
    gzip, # /usr/bin/gzip  (ungz replacement)  -- gunzip/gzip -d
    sed, # /usr/bin/sed   (replace + simple-patch replacement)
  ],
  cmds = [
    # Single handoff to the attested full kaem (same form as R0/B1.5).  PATH/env/cd/control
    # flow all live inside mes.kaem; the inner kaem.x86_64 -> kaem.run M2-Planet build of
    # mes-m2 is invoked from there.
    ["/usr/bin/kaem", "mes.kaem"],
  ],
  outputs = {
    # The from-source subset-C Mes interpreter (static ELF: M2-Planet/hex2 output, no .interp).
    mes_m2 = { glob = "usr/bin/mes-m2", allow_missing_interpreter = true } | OutputBin,
    # The MesCC compiler driver script (Scheme, chmod 755) that R2 runs as `mes-m2 -e main mescc.scm`.
    mescc_scm = { glob = "usr/bin/mescc.scm", allow_executable = true } | OutputData,
    # mes-libc: crt1.{o,s}, libc.{a,s}, libc+tcc.{a,s}, libmescc.{a,s}, x86_64.M1 — R2 links these.
    mes_libs = { glob = "usr/lib/x86_64-mes/**" } | OutputData,
    # ELF header/footer hex2 fragments the mes/tcc link step prepends/appends.
    mes_linux_libs = { glob = "usr/lib/linux/x86_64-mes/**" } | OutputData,
    # mes-libc headers (include/{mes,sys,linux,arch}/ + top-level) — R2's mescc -I include path.
    mes_includes = { glob = "usr/include/**" } | OutputData,
    # Scheme module trees (mes core + mescc + REGENERATED nyacc c99 tables).  NOT installed by
    # upstream pass1.kaem — a hermetic-model addition so R2's MesCC can set GUILE_LOAD_PATH to
    # these (live-bootstrap keeps them in its persistent build tree).  See R1-mes-draft.md §9.
    mes_modules = { glob = "usr/share/mes/**" } | OutputData,
    nyacc_modules = { glob = "usr/share/nyacc/**" } | OutputData,
  },
} | BuildSpec
