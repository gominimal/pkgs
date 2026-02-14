let { standaloneTest, Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
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

let version = "4.10.0" in
{
  name = "findutils",
  inputs = [
    {
      url = "gs://minimal-staging-archives/findutils-%{version}.tar.xz",
      sha256 = "1387e0b67ff247d2abde998f90dfbf70c1491391a59ddfecb8ae698789f0a4f5",
      extract = true,
    } | Source,
    { file = "build.sh" } | Local,
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
    find = { glob = "usr/bin/find" } | OutputBin,
    locate = { glob = "usr/bin/locate" } | OutputBin,
    updatedb = { glob = "usr/bin/updatedb" } | OutputBin,
    xargs = { glob = "usr/bin/xargs" } | OutputBin,

    libexec_frcode = { glob = "usr/libexec/frcode" } | OutputLib,

    mans = { glob = "usr/share/man/**" } | OutputData,
    infos = { glob = "usr/share/info/*.info" } | OutputData,
    locales = { glob = "usr/share/locale/**" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      repology_project = "findutils",
    } | Attrs,

  replace_on_cycle =
    {
      name = "findutils (prebuilt)",
      prebuilt = true,
      inputs = [
        {
          url = "gs://minimal-staging-archives/prebuilts/findutils/arm64-linux-gnu/findutils_4.10.0_arm64-linux-gnu_prebuilt.tar.zst",
          sha256 = "8e859161b0a4f1ef10862da738ed55fb7bd9b21f9833a4e4835e7f2c8b7d4015",
          extract = true,
        } | Source,
      ],
      outputs = {
        usr = { glob = "usr/**/*" } | OutputLib,
      },
    } | BuildSpec,

  tests = {
    smoketest = standaloneTest "/bin/find --version",

    find =
      {
        class = 'Standalone,
        test_deps = [bash, coreutils, grep],
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
