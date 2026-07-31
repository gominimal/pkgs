let { BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
let stage0-tcc-musl-s4 = import "../stage0-tcc-0.9.27-musl-s4/build.ncl" in
let stage0-musl-1_1_24-cc2 = import "../stage0-musl-1.1.24-cc2/build.ncl" in
let stage0-binutils-2_30 = import "../stage0-binutils-2.30/build.ncl" in
# stage0-coreutils — THE CYCLE-BREAKING RUNG.
#
# WHY THIS EXISTS. Measured across packages/stage0-*/build.ncl: 23 bedrock rungs depend on
# `coreutils`, and coreutils/build.ncl imports gcc, glibc and binutils DIRECTLY. Even the rungs
# that already retired bash still pull it — stage0-tcc-0.9.26 runs
# ["/usr/bin/kaem","--strict","--file","tcc.kaem"] with no shell at all and is *still* circular,
# purely through coreutils. That single edge is what forces the 7 toolchain anchors in
# trust-config `bootstrap_artifacts` to remain operator-pinned terminals, because a walk that must
# pass through it can never be acyclic.
#
# The tool surface those rungs actually name is tiny — chmod, cp, mkdir, rm, sha256sum for nearly
# all of them, plus cat/sort/tr/install for one. So this is not a coreutils port; it is a handful
# of utilities built by the bedrock ladder instead of by the compiler the ladder produces.
#
# WHY coreutils 5.0. Modern coreutils (9.x) requires a full autotools configure whose probes and
# gnulib vintage assume a much newer toolchain. 5.0 (2003) is what live-bootstrap uses at an
# equivalent rung. Mirrored 2026-07-31, sha256 below.
#
# EVERY FLAG BELOW WAS MEASURED, NOT GUESSED — see docs/replace-the-bootstraps-plan.md §3e and the
# north-star doc. The experiment hit five walls in order, and each entry here is one of the cures:
#
#   1. crt1.o/crti.o "not found" though present  -> the rung artifacts are built expecting to LIVE
#      at /usr; tcc's crt and include paths are baked. The sandbox installs them there, so no flag
#      is needed here — but it is why a bare-VM reproduction fails and this must be a package.
#   2. bits/alltypes.h ';' expected (got "va_list")  -> WRONG MUSL. stage0-musl-1.2.5 is the
#      GCC-built stock musl ("ZERO of R4's tcc-workaround patches", per its own recipe).
#      stage0-musl-1.1.24-cc2 is the TCC-built one, carrying amd64-va-list.patch which defines
#      __builtin_va_list via tcc's SysV __va_list_struct (__TINYC_va_list_defined).
#   3. "no acceptable ld found in $PATH"  -> stage0-binutils-2.30, itself tcc-built, so no gcc
#      dependency is introduced.
#   4. alloca.h:11 incompatible types for redefinition of 'alloca'  -> musl declares
#      `void *alloca(size_t)` while tcc has a builtin of a different type. -D_ALLOCA_H makes the
#      header a no-op via its own include guard; the header on disk is untouched.
#   5. undefined symbol 'alloca' at link  -> the coherent configure answer. Saying
#      header=no AND works=yes meant neither <alloca.h> NOR coreutils' own lib/alloca.c was used.
#      works=no builds the portable fallback, which supplies the symbol.
#
# STATUS: chmod and rm were built and verified reporting "(coreutils) 5.0" with configure rc=0,
# using only the three deps above — no gcc, no glibc. The remaining tools and the sha256sum
# functional gate were not confirmed before the session lost cloud auth, so this recipe is
# UNPROVEN AS A WHOLE and must not be described otherwise until its gate passes.
#
# DELIBERATELY NOT DEPENDED ON: `coreutils` (the circularity) and `bash` (rung 15). `configure` is
# still a shell script, so this rung needs a shell at build time; that is the next thing to remove
# (live-bootstrap pre-generates config.h and drives make from kaem). Removing it is a separate
# increment — landing the compiler half first is what makes the rest verifiable one rung at a time.
{
  name = "stage0-coreutils",
  version = "5.0",
  build_deps = [
    { file = "build.sh" } | Local,
    { file = "stage0.answers" } | Local, # byte-identity pins, populated from a 2-run comparison
    {
      url = "gs://minimal-staging-archives/coreutils-5.0.tar.gz",
      sha256 = "c27ce75e3f62455f4facf4f3fd55bc9e3877d0ab1d5c0426c94da168cc349883",
      extract = true,
    } | Source,
    stage0-tcc-musl-s4,          # the compiler: tcc-musl2 + libtcc1.a (the "alloca provider")
    stage0-musl-1_1_24-cc2,      # the TCC-COMPATIBLE musl — see wall 2 above
    stage0-binutils-2_30,        # as/ld — see wall 3
  ],
  cmds = [
    ["/bin/sh", "build.sh"],
  ],
  outputs = {
    chmod = { glob = "usr/bin/chmod" } | OutputBin,
    cp = { glob = "usr/bin/cp" } | OutputBin,
    mkdir = { glob = "usr/bin/mkdir" } | OutputBin,
    rm = { glob = "usr/bin/rm" } | OutputBin,
    sha256sum = { glob = "usr/bin/sha256sum" } | OutputBin,
    cat = { glob = "usr/bin/cat" } | OutputBin,
    sort = { glob = "usr/bin/sort" } | OutputBin,
    tr = { glob = "usr/bin/tr" } | OutputBin,
    install = { glob = "usr/bin/install" } | OutputBin,
  },
} | BuildSpec
