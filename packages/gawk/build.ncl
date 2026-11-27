let { standaloneTest, Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base-bootstrap = import "../base-bootstrap/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let glibc = import "../glibc/build.ncl" in
let gawk-bootstrap = import "../gawk-bootstrap/build.ncl" in
let mpfr = import "../mpfr/build.ncl" in
let readline = import "../readline/build.ncl" in

let version = "5.4.2" in
{
  name = "gawk",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/gawk-%{version}.tar.xz",
      sha256 = "b95e4909533b5f988c6b5e5539b3b3ddf76e7d7df02ca2e5b5b7d6f62db78e6a"
    } | Source,
    base-bootstrap,
    make,
    toolchain,
  ],
  runtime_deps = [
    # Provides usr/bin/awk: the same gawk version, built without readline. This
    # package ships every other gawk path but not awk, so the two never install
    # the same file (gominimal/pkgs#973).
    gawk-bootstrap,
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
      license_spdx = "GPL-3.0-only",
      repology_project = "gawk",
      source_provenance = {
        category = 'GnuProject,
        name = "gawk",
      },
    } | Attrs,

  tests = {
    smoketest = standaloneTest "/bin/gawk --version",
    # awk is gawk-bootstrap's, reached through runtime_deps.
    awk_smoketest = standaloneTest "/bin/awk --version",

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
