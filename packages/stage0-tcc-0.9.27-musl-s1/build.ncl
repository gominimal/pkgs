let { BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
# stage0-tcc-0.9.27-musl-s1: builds tcc-musl, a tcc-0.9.27 with the static-GOT linker fix
# (fill_got before tidy_section_headers), compiled by stage0-tcc-0.9.26's tcc against mes
# headers and linked statically against mes crt/libc. The output bakes musl prefixes (/usr/lib,
# /usr/include) for the later musl-linked stages. Deps are mes-side only (no musl), so the
# sandbox carries no mes/musl header collision. Outputs: usr/bin/tcc-musl + x86_64 libtcc1.a.
let stage0-tcc-r2 = import "../stage0-tcc-0.9.26/build.ncl" in # the mes-linked compiler that builds tcc-musl
let stage0-mes = import "../stage0-mes/build.ncl" in # mes headers + mes crt/libc the build links against
let bash = import "../bash/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let tar = import "../tar/build.ncl" in
let gzip = import "../gzip/build.ncl" in
let sed = import "../sed/build.ncl" in
let grep = import "../grep/build.ncl" in
let gawk-bootstrap = import "../gawk-bootstrap/build.ncl" in
let amd64_spec =
  {
    name = "stage0-tcc-0.9.27-musl-s1",
    build_deps = [
      { file = "build.sh" } | Local,
      {
        # tcc-0.9.27 with the stage0-tcc-0.9.27 patch set plus the GOT fix, as a sha-pinned
        # staged tarball. Expressing it as pristine source + patches is a recorded follow-up.
        url = "gs://minimal-staging-archives/tccsrc-r3got-s1.tar.gz",
        sha256 = "f04ba1598543f3f09a0f0b95c9804e00ee7dc5eacfdacf159d6850873eeee3e9",
        extract = false,
      } | Source,
      stage0-tcc-r2,
      stage0-mes,
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
      tcc = { glob = "usr/bin/tcc-musl", allow_missing_interpreter = true } | OutputBin,
      libtcc1 = { glob = "usr/lib/tcc/libtcc1.a" } | OutputLib,
      manifest = { glob = "usr/share/tcc-musl-s1/MANIFEST.txt" } | OutputData,
      logs = { glob = "usr/share/tcc-musl-s1/rows.log" } | OutputData,
    },
  } | BuildSpec
in
# amd64 only: this rung belongs to the hex0-rooted amd64 ladder. On arm64 the spec collapses to
# an empty collection (no build, no outputs, nothing depends on it).
match {
  { arch = 'Amd64, .. } => amd64_spec,
  { arch = 'Arm64, .. } =>
    {
      name = "stage0-tcc-0.9.27-musl-s1",
      build_deps = [],
    } | BuildSpec,
} target
