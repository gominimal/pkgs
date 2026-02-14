let { BuildSpec, Local, OutputData, Source, .. } = import "minimal.ncl" in
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
        {
          url = "gs://minimal-staging-archives/prebuilts/linux_headers/arm64-linux-gnu/linux_headers_6.12_arm64-linux-gnu_prebuilt.tar.zst",
          sha256 = "62e0eb7766a203e65e21561cd6f22f618122c393f2f6a73ad2e44d21c8d45355",
          extract = true,
        } | Source,
      ],
      outputs = {
        includes = { glob = "usr/include/*/**" } | OutputData,
      },
    } | BuildSpec,
} | BuildSpec
