let { standaloneTest, Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
# base
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let bzip2 = import "../bzip2/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let diffutils = import "../diffutils/build.ncl" in
let file = import "../file/build.ncl" in
let findutils = import "../findutils/build.ncl" in
let gawk-bootstrap = import "../gawk-bootstrap/build.ncl" in
let grep = import "../grep/build.ncl" in
let gzip = import "../gzip/build.ncl" in
let make = import "../make/build.ncl" in
let perl = import "../perl/build.ncl" in
let sed = import "../sed/build.ncl" in
let tar = import "../tar/build.ncl" in
let xz = import "../xz/build.ncl" in
# toolchain
let binutils = import "../binutils/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let linux_headers = import "../linux_headers/build.ncl" in
# other
let pcre2 = import "../pcre2/build.ncl" in

let version = "3.12" in
{
  name = "grep",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/grep-%{version}.tar.xz",
      sha256 = "2649b27c0e90e632eadcd757be06c6e9a4f48d941de51e7c0f83ff76408a07b9",
      extract = true,
      strip_prefix = "grep-%{version}",
    } | Source,
    # base
    bash-bootstrap,
    bzip2,
    coreutils,
    diffutils,
    file,
    findutils,
    gawk-bootstrap,
    grep,
    gzip,
    make,
    perl,
    sed,
    tar,
    xz,
    # toolchain
    binutils,
    gcc,
    linux_headers,
    # other
  ],
  runtime_deps = [
    pcre2,
    glibc,
  ],

  cmd = "./build.sh",

  outputs = {
    grep_bin = { glob = "usr/bin/grep" } | OutputBin,
    # Technically egrep & fgrep depend on /bin/sh, but its not practical to depend on bash at such a low level.
    # Disable the lint for now.
    egrep_bin = { glob = "usr/bin/egrep", allow_missing_interpreter = true } | OutputBin,
    fgrep_bin = { glob = "usr/bin/fgrep", allow_missing_interpreter = true } | OutputBin,

    locales = { glob = "usr/share/locale/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "GPL-3.0-only",
      repology_project = "grep",
      source_provenance = {
        category = 'GnuProject,
        name = "grep",
      },
    } | Attrs,

  tests = {
    smoketest = standaloneTest "/bin/grep --version",

    text_matching =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, coreutils],
        cmds = [
          ["/bin/bash", "-c", "echo 'hello world\nfoo bar\nhello again' > test.txt"],
          ["/bin/bash", "-c", "grep hello test.txt | wc -l | grep -q '^2$'"], # verify 2 matches
          ["/bin/bash", "-c", "grep -c hello test.txt | grep -q '^2$'"], # verify count is 2
          ["/bin/bash", "-c", "grep -v foo test.txt | grep -q 'hello world'"], # verify invert match works
          ["/bin/bash", "-c", "grep -i HELLO test.txt | wc -l | grep -q '^2$'"], # verify case insensitive
        ],
      } | Test,
  },
} | BuildSpec
