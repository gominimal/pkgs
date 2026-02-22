let { standaloneTest, Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let bash = import "../bash/build.ncl" in
let binutils = import "../binutils/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let diffutils = import "../diffutils/build.ncl" in
let gawk = import "../gawk/build.ncl" in
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
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/diffutils-%{version}.tar.xz",
      sha256 = "7c8b7f9fc8609141fdea9cece85249d308624391ff61dedaf528fcb337727dfd",
      extract = true,
    } | Source,
    bash,
    binutils,
    coreutils,
    diffutils,
    gawk,
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
      source_provenance = {
        category = 'GnuProject,
        name = "diffutils",
      },
    } | Attrs,

  replace_on_cycle =
    {
      name = "diffutils (prebuilt)",
      prebuilt = true,
      inputs = [
        match {
          { arch = 'Amd64, .. } =>
            {
              url = "gs://minimal-staging-archives/prebuilts/diffutils/c4bfe6f7dd469d90dccbbfa3dc70e77b4ee5fb3c742a548844e618ee89ebf5c8.tar.zst",
              sha256 = "3d309754ed968722a853c82ab9ed01704a4e9f1a88428f47be14e393e7107643",
              extract = true,
            } | Source,
          { arch = 'Arm64, .. } =>
            {
              url = "gs://minimal-staging-archives/prebuilts/diffutils/arm64-linux-gnu/diffutils_3.12_arm64-linux-gnu_prebuilt.tar.zst",
              sha256 = "1ee320081cf6a49e878bd341dc96f593707ef17574d74cd9b3da913b45503d93",
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
        test_deps = [bash, coreutils],
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
