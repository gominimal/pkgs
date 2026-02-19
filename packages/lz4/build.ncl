let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .., } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let bash = import "../bash/build.ncl" in
let tar = import "../tar/build.ncl" in
let make = import "../make/build.ncl" in
let sed = import "../sed/build.ncl" in
let grep = import "../grep/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let diffutils = import "../diffutils/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let glibc = import "../glibc/build.ncl" in
{
  name = "lz4",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/lz4-1.10.0.tar.gz",
      sha256 = "537512904744b35e232912055ccf8ec66d768639ff3abe5788d90d792ec5f48b"
    } | Source,
    bash,
    tar,
    make,
    sed,
    grep,
    coreutils,
    diffutils,
    toolchain,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  outputs = {
    lz4 = { glob = "usr/bin/lz4" } | OutputBin,
    lz4c = { glob = "usr/bin/lz4c" } | OutputBin,
    lz4cat = { glob = "usr/bin/lz4cat" } | OutputBin,
    unlz4 = { glob = "usr/bin/unlz4" } | OutputBin,

    liblz4 = { glob = "usr/lib/liblz4.so*" } | OutputLib,

    pkgconfigs = { glob = "usr/lib/pkgconfig/**" } | OutputData,

    mans = { glob = "usr/share/man/**" } | OutputData,
    includes = { glob = "usr/include/**" } | OutputData,
  },

  replace_on_cycle =
    {
      name = "lz4 (prebuilt)",
      prebuilt = true,
      inputs = [
        match {
          { arch = 'Amd64, .. } =>
            {
              url = "gs://minimal-staging-archives/prebuilts/lz4/fbd8d1e9a8c1cb2987f8264b4b86466e4e6c185cae545f5ab5f4f40a45525730.tar.zst",
              sha256 = "e346a414f9ce3fcbd0d190aa835c9bc5881019919f4dcbb99e4e661cb9c77b34",
              extract = true,
            } | Source,
          { arch = 'Arm64, .. } =>
            {
              url = "gs://minimal-staging-archives/prebuilts/lz4/arm64-linux-gnu/lz4_1.10.0_arm64-linux-gnu_prebuilt.tar.zst",
              sha256 = "617c89cfe20a50d7337ddff8d4134d60741abb8f0a57bc6f99bb4c275742c877",
              extract = true,
            } | Source,
        } target,
      ],
      outputs = {
        lz4 = { glob = "usr/bin/lz4" } | OutputBin,
        lz4c = { glob = "usr/bin/lz4c" } | OutputBin,
        lz4cat = { glob = "usr/bin/lz4cat" } | OutputBin,
        unlz4 = { glob = "usr/bin/unlz4" } | OutputBin,
        liblz4 = { glob = "usr/lib/liblz4.so*" } | OutputLib,
        pkgconfigs = { glob = "usr/lib/pkgconfig/**" } | OutputData,
        mans = { glob = "usr/share/man/**" } | OutputData,
        includes = { glob = "usr/include/**" } | OutputData,
      },
    } | BuildSpec,
  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GithubRepo,
        owner = "lz4",
        repo = "lz4",
      },
    } | Attrs,
} | BuildSpec
