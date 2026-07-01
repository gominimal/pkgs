let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
# ============================================================================================
# R6 — stage0-gcc-4.0.4 (core, pass1) — DRAFT 2026-06-30. NOT BUILDABLE UNTIL R5 IS GREEN.
# ============================================================================================
# THE C-ONLY KEYSTONE (U1). The first from-source gcc in the bedrock climb: gcc-core 4.0.4,
# compiled by the SEALED tcc-musl2 (R4a/s4, musl-linked, A+B+C GOT fixes, correctness-gated),
# linked against R4 musl, assembled/archived by R5 binutils-2.30 — producing cc1 + xgcc + cpp +
# libgcc.a. R7 (musl-1.2.5) and R8 (gmp/mpfr/mpc) build ON this gcc.
#
# WHY THIS IS A DRAFT (parallel-safe prep; gated on R5):
#   - R5 binutils-2.30 must SEAL first: gcc's build needs `as`/`ld`/`ar`/`ranlib`/`nm` on PATH
#     (xgcc assembles libgcc2.c via `as`; the env sets no system AR/RANLIB). Sequencing rule from
#     .staging-ctx/bedrock-amd64-readiness-2026-06-26.md §"Critical sequencing": R5 -> R6 -> R7/R8.
#   - tcc-musl2 must be SEALED in RemoteCache (s4 GATE-PASS) before this build, else the builder
#     re-runs the s1/s3 mes-libc lottery in-task per cycle. We import s4 (the gated seal), NOT s3.
#
# THE CORRECTION THIS DRAFT MAKES vs the prior R6 sketch (ladder-prep DO-NOW): the old draft used
# raw `CC=tcc` (R3 mes-prefixed tcc) and WOULD NOT LINK. This recipe ports R5's musl-cc WRAPPER
# verbatim (CC=wrapper over the sealed tcc-musl2; AR="tcc-musl2 -ar") so the abort/libtcc1<->libc
# static-link cycle resolves. See build.sh header + .staging-ctx/bedrock-ladder-prep-2026-06-29.md §iv.B.
#
# MODEL-B (verified 2026-06-30 against the e9bf58c7 tarball): gcc-core-4.0.4 SHIPS every generated
# file (configure, Makefile.in, c-parse.{c,h,y}, gengtype-yacc.{c,h}, gengtype-lex.c, intl/plural.c,
# libcpp/ucnid.h, fixincludes/fixincl.x, config.sub). The bedrock env has NO autoconf/automake/bison/
# flex/perl/m4 -> live-bootstrap pass1.sh's heavy Model-A regen is INFEASIBLE -> we SKIP all regen,
# ship the generated files, and pin their mtimes newest (build.sh mtime guard) so make never tries to
# rebuild them. Only the 3 load-bearing SOURCE seds from pass1.sh are hand-ported (tcc + musl compat).
#
# config.sub: NO donor swap. The shipped 2005 config.sub canonicalizes x86_64-linux-gnu (verified) =>
# the automake-1.16.3 distfile live-bootstrap pulls is DROPPED (it only existed to feed a regen we skip).
# ============================================================================================
let stage0-tcc-musl-s4 = import "../stage0-tcc-0.9.27-musl-s4/build.ncl" in   # R4a SEAL: gate-passed /usr/bin/tcc-musl2 + /usr/lib/tcc/libtcc1.a (CC + AR)
let stage0-musl-r4 = import "../stage0-musl-1.1.24-cc2/build.ncl" in          # R4b (2026-07-01: was R4a) — DETERMINISTIC sealed-correct musl + /usr/lib/musl-bedrock clean sysroot (link target)
let stage0-binutils-r5 = import "../stage0-binutils-2.30/build.ncl" in        # R5: as/ld/ar/ranlib/nm on PATH (xgcc->as for libgcc; archives) — MUST seal first
let bash = import "../bash/build.ncl" in                                      # ./build.sh driver + configure shell
let make = import "../make/build.ncl" in                                      # build engine
let sed = import "../sed/build.ncl" in                                        # the 3 source seds + config.* edits
let grep = import "../grep/build.ncl" in                                      # configure probes
let coreutils = import "../coreutils/build.ncl" in                            # rm/mkdir/cp/ln/touch/sha256sum
let tar = import "../tar/build.ncl" in                                        # build.sh `tar -xf`
let bzip2 = import "../bzip2/build.ncl" in                                    # gcc-core ships .tar.bz2 (R4 was .gz, R5 .xz)
let findutils = import "../findutils/build.ncl" in                            # mtime guard: find . -exec touch (Model-B regen avoidance)
let gawk-bootstrap = import "../gawk-bootstrap/build.ncl" in                  # configure's awk
let version = "4.0.4" in
{
  name = "stage0-gcc-4.0.4",
  build_deps = [
    { file = "build.sh" } | Local,
    # RECORD-AT-PIN-TIME byte-identity pins (no upstream amd64 gcc-4.0.4 fixed point; live-bootstrap
    # is i386). Capture cc1/xgcc/cpp/libgcc.a shas after the first green CS build, then re-enable the
    # `sha256sum -c` gate at the tail of build.sh.
    { file = "stage0.answers" } | Local,
    {
      # upstream gcc-core 4.0.4 (.tar.bz2). sha256 from live-bootstrap steps/gcc-4.0.4/sources,
      # mirrored byte-identically to our archives bucket (sha preserved -> sha-pinned resolvedDeps;
      # confirmed present 2026-06-30: gs://minimal-staging-archives/gcc-core-4.0.4.tar.bz2 15583411B).
      # extract=false — build.sh runs `tar -xf` itself (bash-build convention; extracts to gcc-4.0.4/).
      url = "gs://minimal-staging-archives/gcc-core-%{version}.tar.bz2",
      sha256 = "e9bf58c761a4f988311aef6b41f12fd5c7e51d09477468fb73826aecc1be32e7",
      extract = false,
    } | Source,
    stage0-tcc-musl-s4,   # R4a SEAL: tcc-musl2 (CC via musl-cc wrapper) + libtcc1.a + AR="tcc-musl2 -ar"
    stage0-musl-r4,       # R4: libc.a + crt1/crti/crtn + headers (the static link target)
    stage0-binutils-r5,   # R5: as/ld/ar/ranlib/nm on PATH (xgcc->as for libgcc; archive index)
    bash,
    make,
    sed,
    grep,
    coreutils,
    tar,
    bzip2,
    findutils,
    gawk-bootstrap,
  ],
  build_args = {
    include version,
  },
  cmd = "./build.sh",
  outputs = {
    # the gcc drivers R7+ use as CC (gcc/cpp/gcov + the x86_64-linux-gnu-prefixed driver). OutputData
    # (not OutputBin) mirrors R5 binutils: these are static-musl execs whose interpreter check we skip.
    bin = { glob = "usr/bin/*" } | OutputData,
    # cc1 + collect2 (the real compiler + link wrapper):
    libexec = { glob = "usr/libexec/**" } | OutputData,
    # libgcc.a + crtbegin/crtend.o + specs + gcc's internal headers (the C runtime R7+ links against).
    # ONE non-overlapping glob (mirrors R5 binutils' disjoint outputs): libgcc.a lives UNDER this tree
    # at usr/lib/gcc/<target>/<ver>/ and is found via gcc's own internal search path, not a global lib
    # path, so OutputData over the whole subtree is sufficient (no separate OutputLib needed).
    internals = { glob = "usr/lib/gcc/**" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      repology_project = "gcc",
    } | Attrs,
} | BuildSpec
