let { BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let bash = import "../bash/build.ncl" in
let binutils = import "../binutils/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let gawk = import "../gawk/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let grep = import "../grep/build.ncl" in
let make = import "../make/build.ncl" in
let linux_headers = import "../linux_headers/build.ncl" in
let sed = import "../sed/build.ncl" in
{
  name = "attr",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/attr-2.5.2.tar.gz",
      sha256 = "39bf67452fa41d0948c2197601053f48b3d78a029389734332a6309a680c6c87",
      extract = true,
      strip_prefix = "attr-2.5.2",
    } | Source,
    bash,
    binutils,
    coreutils,
    gawk,
    gcc,
    glibc,
    grep,
    make,
    linux_headers,
    sed,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  outputs = {
    bins = { glob = "usr/bin/*" } | OutputBin,
    libs = { glob = "usr/lib/*.{a,so*}" } | OutputLib,

    ltconfigs = { glob = "usr/lib/libattr.la" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/**" } | OutputData,

    etcs = { glob = "etc/*" } | OutputData,
    mans = { glob = "usr/share/man/**" } | OutputData,
    includes = { glob = "usr/include/**" } | OutputData,
    locales = { glob = "usr/share/locale/**" } | OutputData,
  },

  replace_on_cycle =
    {
      name = "attr (prebuilt)",
      prebuilt = true,
      inputs = [
        match {
          { arch = 'Amd64, .. } =>
            {
              url = "gs://minimal-staging-archives/prebuilts/attr/1e7c99dbb23c903b50fa6f1093a1f629e135cbfd906a95a261816f4d96170728.tar.zst",
              sha256 = "b6e4e7fb2f1b177c43e4b3ac88f24bb9a41b47f91de987351349a12838b06a45",
              extract = true,
            } | Source,
          { arch = 'Arm64, .. } =>
            {
              url = "gs://minimal-staging-archives/prebuilts/attr/arm64-linux-gnu/attr_2.5.2_arm64-linux-gnu_prebuilt.tar.zst",
              sha256 = "dc1947748102f63ced5a5770604034e7bf35bf1a5173ad93fd4d049518a2ab93",
              extract = true,
            } | Source,
        } target,
      ],
      outputs = {
        usr = { glob = "usr/**/*" } | OutputLib,
      },
    } | BuildSpec,
} | BuildSpec
