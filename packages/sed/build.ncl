let { standaloneTest, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let acl = import "../acl/build.ncl" in
let attr = import "../attr/build.ncl" in
let bash = import "../bash/build.ncl" in
let binutils = import "../binutils/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let findutils = import "../findutils/build.ncl" in
let gawk = import "../gawk/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let grep = import "../grep/build.ncl" in
let linux_headers = import "../linux_headers/build.ncl" in
let make = import "../make/build.ncl" in
let sed = import "../sed/build.ncl" in
let tar = import "../tar/build.ncl" in

let version = "4.9" in
{
  name = "sed",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/sed-%{version}.tar.xz",
      sha256 = "6e226b732e1cd739464ad6862bd1a1aba42d7982922da7a53519631d24975181"
    } | Source,
    acl,
    bash,
    binutils,
    coreutils,
    findutils,
    gawk,
    gcc,
    glibc,
    grep,
    linux_headers,
    make,
    sed,
    tar,
  ],
  runtime_deps = [
    acl,
  ],

  cmd = "./build.sh",
  outputs = {
    sed = { glob = "usr/bin/sed" } | OutputBin,

    mans = { glob = "usr/share/man/**" } | OutputData,
    infos = { glob = "usr/share/info/*.info" } | OutputData,
    locales = { glob = "usr/share/locale/**" } | OutputData,
  },
  attrs.upstream_version = version,

  replace_on_cycle =
    {
      name = "sed (prebuilt)",
      prebuilt = true,
      inputs = [
        match {
          { arch = 'Amd64, .. } =>
            {
              url = "gs://minimal-staging-archives/prebuilts/sed/b2454441fcc0966caa42b1a66c39de67ed9f4fbf507443a4443313b2d955e43d.tar.zst",
              sha256 = "0545b519704c923b41c2a704eb5162245f7496d35df09deeb051f54a7a218bed",
              extract = true,
            } | Source,
          { arch = 'Arm64, .. } =>
            {
              url = "gs://minimal-staging-archives/prebuilts/sed/arm64-linux-gnu/sed_4.9_arm64-linux-gnu_prebuilt.tar.zst",
              sha256 = "8ed9f3fdc9037e64425cdb5471b2dffde7d481e8296f9bc2acff4e79512b449d",
              extract = true,
            } | Source,
        } target,
      ],
      # TODO: runtime_deps in a cycle breaker are borked?
      # runtime_deps = [
      #   acl,
      #   attr,
      # ],
      outputs = {
        sed = { glob = "usr/bin/sed" } | OutputBin,
      },
    } | BuildSpec,

  tests = {
    smoketest = standaloneTest "/bin/sed --version",

    text =
      {
        class = 'Standalone,
        test_deps = [bash, coreutils, grep],
        cmds = [
          # verify substitution
          ["/bin/bash", "-c", "echo 'hello world' > input.txt"],
          ["/bin/bash", "-c", "sed 's/world/universe/' input.txt > output.txt"],
          ["/bin/bash", "-c", "grep -q 'hello universe' output.txt"],
          # verify in-place edit
          ["/bin/bash", "-c", "echo 'hello world' > input2.txt"],
          ["/bin/sed", "-i", "s/hello/hi/", "input2.txt"],
          ["/bin/bash", "-c", "grep -q '^hi world$' input2.txt"],
          # verify line extraction
          ["/bin/bash", "-c", "echo 'line1\nline2\nline3' > multi.txt"],
          ["/bin/bash", "-c", "sed -n '2p' multi.txt | grep -q '^line2$'"],
        ],
      } | Test,
  },
} | BuildSpec
