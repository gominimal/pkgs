let { standaloneTest, Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base-bootstrap = import "../base-bootstrap/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let glibc = import "../glibc/build.ncl" in
let mpfr = import "../mpfr/build.ncl" in
let readline = import "../readline/build.ncl" in

let version = "5.4.0" in
{
  name = "gawk",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/gawk-%{version}.tar.xz",
      sha256 = "3dd430f0cd3b4428c6c3f6afc021b9cd3c1f8c93f7a688dc268ca428a90b4ac1"
    } | Source,
    base-bootstrap,
    make,
    toolchain,
  ],
  runtime_deps = [
    glibc,
    mpfr,
    readline,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    "gawk-%{version}" = { glob = "usr/bin/gawk-%{version}" } | OutputBin,
    gawk = { glob = "usr/bin/gawk" } | OutputBin,
    awk = { glob = "usr/bin/awk" } | OutputBin,
    libs = { glob = "usr/lib/gawk/*.so" } | OutputLib,
    libexec = { glob = "usr/libexec/awk/*" } | OutputLib,

    includes = { glob = "usr/include/**" } | OutputData,

    awk_data = { glob = "usr/share/awk/*" } | OutputData,
    mans = { glob = "usr/share/man/**" } | OutputData,
    locales = { glob = "usr/share/locale/**" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      repology_project = "gawk",
      source_provenance = {
        category = 'GnuProject,
        name = "gawk",
      },
    } | Attrs,

  tests = {
    smoketest = standaloneTest "/bin/gawk --version",

    matching =
      {
        class = 'Standalone,
        test_deps = [base-bootstrap],
        cmds = [
          ["/bin/bash", "-c", "echo 'one two three\nfour five six' > data.txt"],
          ["/bin/bash", "-c", "gawk '{print $2}' data.txt > col2.txt"],
          ["/bin/bash", "-c", "echo 'two\nfive' > expected.txt"],
          ["/bin/diff", "-q", "col2.txt", "expected.txt"], # verify second column extracted
          ["/bin/bash", "-c", "gawk '/five/ {print $1}' data.txt | grep -q '^four$'"], # verify pattern matching
        ],
      } | Test,
  },
} | BuildSpec
