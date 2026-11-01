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

let version = "3.12" in
{
  name = "diffutils",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/diffutils-%{version}.tar.xz",
      sha256 = "7c8b7f9fc8609141fdea9cece85249d308624391ff61dedaf528fcb337727dfd",
      extract = true,
    } | Source,
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
    cmp = { glob = "usr/bin/cmp" } | OutputBin,
    diff = { glob = "usr/bin/diff" } | OutputBin,
    diff3 = { glob = "usr/bin/diff3" } | OutputBin,
    sdiff = { glob = "usr/bin/sdiff" } | OutputBin,

    mans = { glob = "usr/share/man/**" } | OutputData,
    infos = { glob = "usr/share/info/*.info" } | OutputData,
    locales = { glob = "usr/share/locale/**" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "GPL-3.0-only",
      source_provenance = {
        category = 'GnuProject,
        name = "diffutils",
      },
    } | Attrs,

  replace_on_cycle =
    {
      name = "diffutils (prebuilt)",
      prebuilt = true,
      build_deps = [
        match {
          { arch = 'Amd64, .. } =>
            {
              # gominimal/bootstrap gen-11 object (generations/gen-11/manifest.json)
              url = "gs://minimal-bootstrap/gen-11/sha256/a39e9488320aa706957c752e7b663c3d2defc842dd162775936858b5ec760771/diffutils-x86_64.tar.zst",
              sha256 = "a39e9488320aa706957c752e7b663c3d2defc842dd162775936858b5ec760771",
              extract = true,
            } | Source,
          { arch = 'Arm64, .. } =>
            {
              # gominimal/bootstrap gen-11 object (generations/gen-11/manifest.json)
              url = "gs://minimal-bootstrap/gen-11/sha256/25f9e709c9b660b87f95628efb655eb2e4724d5ab91e0928253c99aa92e43350/diffutils-aarch64.tar.zst",
              sha256 = "25f9e709c9b660b87f95628efb655eb2e4724d5ab91e0928253c99aa92e43350",
              extract = true,
            } | Source,
        } target,
      ],
      outputs = {
        usr_bin = { glob = "usr/bin/**/*" } | OutputLib,
        usr_share = { glob = "usr/share/**/*" } | OutputLib,
      },
    } | BuildSpec,

  tests = {
    smoketest = standaloneTest "/bin/cmp --version",

    diff =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, coreutils],
        cmds = [
          ["/bin/bash", "-c", "echo 'hello world' > test1.txt"],
          ["/bin/bash", "-c", "echo 'hello whrld' > test2.txt"],
          # Differs
          ["/bin/bash", "-c", "diff -q test1.txt test2.txt || echo worked"],
          # Matches
          ["/bin/diff", "-q", "test2.txt", "test2.txt"],
        ],
      } | Test,
  },
} | BuildSpec
