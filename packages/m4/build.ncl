let { BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "1.4.20" in
{
  name = "m4",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/m4-%{version}.tar.xz",
      sha256 = "e236ea3a1ccf5f6c270b1c4bb60726f371fa49459a8eaaebc90b216b328daf2b",
      extract = true,
      strip_prefix = "m4-%{version}",
    } | Source,
    base,
    make,
    toolchain,
  ],

  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  outputs = {
    bins = { glob = "usr/bin/*" } | OutputBin,

    mans = { glob = "usr/share/man/**" } | OutputData,
    infos = { glob = "usr/share/info/*.info" } | OutputData,
    locales = { glob = "usr/share/locale/**" } | OutputData,
  },

  replace_on_cycle =
    {
      name = "m4 (prebuilt)",
      prebuilt = true,
      inputs = [
        {
          url = "gs://minimal-staging-archives/prebuilts/m4/arm64-linux-gnu/m4_1.4.21_arm64-linux-gnu_prebuilt.tar.zst",
          sha256 = "2f11a263e0c2ea099c57fb506081a6c65a0f802191ac8ae5f09188f0f95e969a",
          extract = true,
        } | Source,
      ],
      outputs = {
        bins = { glob = "usr/bin/**/*" } | OutputBin,
        mans = { glob = "usr/share/man/**" } | OutputData,
        infos = { glob = "usr/share/info/*.info" } | OutputData,
        locales = { glob = "usr/share/locale/**" } | OutputData,
      },
    } | BuildSpec,
} | BuildSpec
