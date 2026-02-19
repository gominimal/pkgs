let { Attrs, BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
# base
let bash = import "../bash/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let findutils = import "../findutils/build.ncl" in
let grep = import "../grep/build.ncl" in
let make = import "../make/build.ncl" in
let sed = import "../sed/build.ncl" in
let tar = import "../tar/build.ncl" in
let xz = import "../xz/build.ncl" in
# toolchain
let binutils = import "../binutils/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let linux_headers = import "../linux_headers/build.ncl" in
{
  name = "linux_headers",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/linux-6.12.43.tar.xz",
      sha256 = "0fcbbbbcd456e87bbbfc8bf37af541fda62ccfcce76903503424fd101ef7bdee"
    } | Source,
    bash,
    coreutils,
    findutils,
    grep,
    make,
    sed,
    tar,
    xz,
    # toolchain
    binutils,
    gcc,
    glibc,
    linux_headers
  ],
  cmd = "./build.sh",
  outputs = {
    includes = { glob = "usr/include/*/**" } | OutputData,
  },

  replace_on_cycle =
    {
      name = "linux_headers (prebuilt)",
      prebuilt = true,
      inputs = [
        match {
          { arch = 'Amd64, .. } =>
            {
              url = "gs://minimal-staging-archives/prebuilts/linux_headers/06b2114a47cb8be25785fa4fae5b2d5c18a21b6dac059dcfd50577fb16e688a9.tar.zst",
              sha256 = "353a3bc9146169c825d8ee9cfc40338f943e352b498bc19626720507328f5328",
              extract = true,
            } | Source,
          { arch = 'Arm64, .. } =>
            {
              url = "gs://minimal-staging-archives/prebuilts/linux_headers/arm64-linux-gnu/linux_headers_6.12_arm64-linux-gnu_prebuilt.tar.zst",
              sha256 = "36111828331168cfd3419a1adff75e006c944dcb0d236f378dbbf1d7dbd0c026",
              extract = true,
            } | Source,
        } target,
      ],
      outputs = {
        includes = { glob = "usr/include/*/**" } | OutputData,
      },
    } | BuildSpec,
  attrs =
    {
      source_provenance = {
        category = 'GithubRepo,
        owner = "torvalds",
        repo = "linux",
      },
    } | Attrs,
} | BuildSpec
