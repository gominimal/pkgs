let { BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
# stage0-tcc-0.9.27-musl-s3: the musl relink. s1's mes-linked tcc-musl recompiles tcc.c against
# musl (stage0-musl-1.1.24) into tcc-musl2, a musl-linked tcc that does not depend on mes-libc
# at runtime. Deps are musl-side only (no mes), so /usr/include is pure musl.
# Outputs: usr/bin/tcc-musl2 + s1's libtcc1.a passed through.
let stage0-musl-1-1-24 = import "../stage0-musl-1.1.24/build.ncl" in
let stage0-tcc-0-9-27-musl-s1 = import "../stage0-tcc-0.9.27-musl-s1/build.ncl" in
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
        # tcc-0.9.27 with the stage0-tcc-0.9.27 patch set plus GOT fixes A, B, C; the same
        # sha-pinned tarball s4 recompiles for its fixed-point check.
        url = "gs://minimal-staging-archives/tccsrc-r3gotABC.tar.gz",
        sha256 = "4267860f408f2df455116bc7e7ee9cee874cc81339841d0760a2a0261803ae79",
        extract = false,
      } | Source,
      stage0-musl-1-1-24,
      stage0-tcc-0-9-27-musl-s1,
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
# amd64 only: this rung belongs to the hex0-rooted amd64 ladder. On arm64 the spec collapses to
# an empty collection (no build, no outputs, nothing depends on it).
match {
  { arch = 'Amd64, .. } => amd64_spec,
  { arch = 'Arm64, .. } =>
    {
      name = "stage0-tcc-0.9.27-musl-s3",
      build_deps = [],
    } | BuildSpec,
} target
