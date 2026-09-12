let { BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
# R4a STAGE 3 — stage0-tcc-0.9.27-musl-s3.  The MUSL-RELINK (two-stage stability).  s1's tcc-musl is
# mes-linked -> flaky on big compiles/links (the mes-libc lottery).  Now that it LINKS running musl
# binaries (fixes A+B+C), have it rebuild tcc.c against MUSL -> tcc-musl2, a MUSL-LINKED tcc that escapes
# the mes-libc lottery (stable) and is the stress-test for the upcoming binutils build.  Clean MUSL env:
# deps R4 (musl) + s1 (the mes-linked tcc-musl + libtcc1.a) ONLY — no R1, so /usr/include is pure musl.
let stage0-musl-r4 = import "../stage0-musl-1.1.24/build.ncl" in
let stage0-tcc-musl-s1 = import "../stage0-tcc-0.9.27-musl-s1/build.ncl" in
let bash = import "../bash/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let tar = import "../tar/build.ncl" in
let gzip = import "../gzip/build.ncl" in
let sed = import "../sed/build.ncl" in
let grep = import "../grep/build.ncl" in
let gawk-bootstrap = import "../gawk-bootstrap/build.ncl" in
let amd64_spec =
  {
    name = "stage0-tcc-0.9.27-musl-s3",
    build_deps = [
      { file = "build.sh" } | Local,
      {
        # tcc-0.9.27 + R3 patches + GOT fixes A,B,C (shared byte-for-byte with s4).  Was an
        # in-repo blob; now a sha-pinned staged Source — same rationale as s1.
        url = "gs://minimal-staging-archives/tccsrc-r3gotABC.tar.gz",
        sha256 = "4267860f408f2df455116bc7e7ee9cee874cc81339841d0760a2a0261803ae79",
        extract = false,
      } | Source,
      stage0-musl-r4,
      stage0-tcc-musl-s1,
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
      tcc = { glob = "usr/bin/tcc-musl2", allow_missing_interpreter = true } | OutputBin,
      libtcc1 = { glob = "usr/lib/tcc/libtcc1.a" } | OutputLib,
      manifest = { glob = "usr/share/tcc-musl-s3/MANIFEST.txt" } | OutputData,
      logs = { glob = "usr/share/tcc-musl-s3/rows.log" } | OutputData,
    },
  } | BuildSpec
in
# ARCH SCOPE (buildbot builds every member on BOTH arches): this rung exists on
# amd64 only — it belongs to the hex0-rooted amd64 bootstrap ladder. arm64's
# equivalents are the SEALED bedrock artifacts consumed as sha-pinned Sources
# by the flip specs (#631/#667), so on arm64 this spec collapses to an
# explicitly-EMPTY collection: no build runs, nothing ships, and nothing on the
# arm graph depends on it.
match {
  { arch = 'Amd64, .. } => amd64_spec,
  { arch = 'Arm64, .. } =>
    {
      name = "stage0-tcc-0.9.27-musl-s3",
      build_deps = [],
    } | BuildSpec,
} target
