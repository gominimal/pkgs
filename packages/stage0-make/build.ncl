let { Attrs, BuildSpec, Local, OutputBin, Source, .. } = import "minimal.ncl" in
# ============================================================================================
# stage0-make — the first USERLAND rung of the bedrock ladder.
#
# WHY THIS EXISTS. The base soup's remaining prebuilts form ONE 21-node strongly-connected
# component. Measured 2026-08-06: 0/23 single-edge cuts, 0/23 pair cuts (1108 plans), and NO
# vertex set of size <=7 makes it acyclic. Nine members carry literal self-loops — make among
# them — and a self-loop is only removable by removing the vertex, so the minimum feedback vertex
# set is >= 9. Edge-cutting cannot dissolve this knot.
#
# What does is the pattern stage0-linux-headers-6.12.43 already proves: build the SAME source
# from bedrock deps only, with no dependency on the package itself. make is the highest-leverage
# place to start — in-degree 23, the most depended-on node in the knot.
#
# HOW THE SELF-LOOP IS BROKEN. GNU make ships a bootstrap path: configure emits build.sh (from
# build.sh.in), a plain shell script that compiles make WITHOUT make. Verified end-to-end on
# aarch64 against the sealed bedrock gcc with make deliberately absent from PATH — rc=0, result
# reports `GNU Make 4.4.1`, and it can drive a makefile (probe MBP_BOOTSTRAP_OK).
#
# DEP MODEL follows stage0-linux-headers: the ONLY compiler is the bedrock summit, binutils
# supplies ar/ranlib/as/ld, musl is the sysroot. Userland deps are the few tools configure and
# build.sh actually shell out to — and NOT make, which is the whole point.
# ============================================================================================
let stage0-gcc = import "../stage0-gcc-15.2.0/build.ncl" in
let stage0-binutils = import "../stage0-binutils-2.41/build.ncl" in
let stage0-musl = import "../stage0-musl-1.1.24/build.ncl" in
let bash = import "../bash/build.ncl" in
let sed = import "../sed/build.ncl" in
let grep = import "../grep/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let gawk-bootstrap = import "../gawk-bootstrap/build.ncl" in
let tar = import "../tar/build.ncl" in
let gzip = import "../gzip/build.ncl" in
let version = "4.4.1" in
{
  name = "stage0-make",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      # SAME source + sha as production packages/make.
      url = "gs://minimal-staging-archives/make-%{version}.tar.gz",
      sha256 = "dd16fb1d67bfab79a72f5e8390735c49e3e8e70b4945a15ab1f81ddb78658fb3",
      extract = false,
    } | Source,
    stage0-gcc,
    stage0-binutils,
    stage0-musl,
    bash,
    sed,
    grep,
    coreutils,
    gawk-bootstrap,
    tar,
    gzip,
    # DELIBERATELY ABSENT: make. build.sh bootstraps without it, and build.sh refuses to run if
    # make is on PATH so this rung can never silently regain the dependency it exists to remove.
  ],
  build_args = {
    include version,
  },
  cmd = "./build.sh",
  outputs = {
    bin = { glob = "usr/bin/make" } | OutputBin,
  },
} | BuildSpec
