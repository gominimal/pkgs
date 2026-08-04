let { standaloneTest, Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let binutils = import "../binutils/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let diffutils = import "../diffutils/build.ncl" in
let gawk-bootstrap = import "../gawk-bootstrap/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let grep = import "../grep/build.ncl" in
let make = import "../make/build.ncl" in
let linux_headers = import "../linux_headers/build.ncl" in
let sed = import "../sed/build.ncl" in
let tar = import "../tar/build.ncl" in

let version = "4.11.0" in
{
  name = "findutils",
  build_deps = [
    {
      url = "gs://minimal-staging-archives/findutils-%{version}.tar.xz",
      sha256 = "bfd19cb06cc71f3352d567e90284d8cdac02ac89774bbeadf0b533b0c11432fd",
      extract = true,
    } | Source,
    { file = "build.sh" } | Local,
    bash-bootstrap,
    binutils,
    coreutils,
    diffutils,
    gawk-bootstrap,
    gcc,
    glibc,
    grep,
    make,
    linux_headers,
    sed,
    tar,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    find = { glob = "usr/bin/find" } | OutputBin,
    locate = { glob = "usr/bin/locate" } | OutputBin,
    # Technically updatedb depends on /bin/sh, but its not practical to depend on bash at such a low level.
    # Disable the lint for now.
    updatedb = { glob = "usr/bin/updatedb", allow_missing_interpreter = true } | OutputBin,
    xargs = { glob = "usr/bin/xargs" } | OutputBin,

    libexec_frcode = { glob = "usr/libexec/frcode" } | OutputLib,

    mans = { glob = "usr/share/man/**" } | OutputData,
    infos = { glob = "usr/share/info/*.info" } | OutputData,
    locales = { glob = "usr/share/locale/**" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GnuProject,
        name = "findutils",
      },
      license_spdx = "GPL-3.0-only",
      repology_project = "findutils",
    } | Attrs,

  tests = {
    smoketest = standaloneTest "/bin/find --version",

    find =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, coreutils, grep],
        cmds = [
          ["/bin/bash", "-c", "mkdir -p testdir && echo 'data' > testdir/test.txt"],
          ["/bin/bash", "-c", "touch testdir/other.log"],
          # verify find result
          ["/bin/bash", "-c", "find testdir -name '*.txt' | grep -q 'test.txt'"],
          # verify 2 files
          ["/bin/bash", "-c", "find testdir -type f | wc -l | grep -q '^2$'"],
        ],
      } | Test,
  },
} | BuildSpec
