let { BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
# base
let bash = import "../bash/build.ncl" in
let bzip2 = import "../bzip2/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let diffutils = import "../diffutils/build.ncl" in
let file = import "../file/build.ncl" in
let findutils = import "../findutils/build.ncl" in
let gawk = import "../gawk/build.ncl" in
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
let gmp = import "../gmp/build.ncl" in
let mpfr = import "../mpfr/build.ncl" in
{
  name = "mpc",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/mpc-1.3.1.tar.gz",
      sha256 = "ab642492f5cf882b74aa0cb730cd410a81edcdbec895183ce930e706c1c759b8"
    } | Source,
    # base
    bash,
    bzip2,
    coreutils,
    diffutils,
    file,
    findutils,
    gawk,
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
    glibc,
    linux_headers,
  ],
  runtime_deps = [
    glibc,
    gmp,
    mpfr,
  ],

  cmd = "./build.sh",
  outputs = {
    libs = { glob = "usr/lib/libmpc.so*" } | OutputLib,

    ltconfigs = { glob = "usr/lib/libmpc.la" } | OutputData,
    includes = { glob = "usr/include/mpc.h" } | OutputData,
    infos = { glob = "usr/share/info/*.info" } | OutputData,
  },
  replace_on_cycle =
    {
      name = "mpc (prebuilt)",
      prebuilt = true,
      inputs = [
        match {
          { arch = 'Amd64, .. } =>
            {
              url = "gs://minimal-staging-archives/prebuilts/mpc/94ebf966b773423844ef6b2b620c062f31e8479bbe9e97ad808e414b558743a7.tar.zst",
              sha256 = "a3bb4b9e9bfcb0e2018065dd0036f2943cf0b5fda8aebb56f477026531ba7fdd",
              extract = true,
            } | Source,
          { arch = 'Arm64, .. } =>
            {
              url = "gs://minimal-staging-archives/prebuilts/mpc/arm64-linux-gnu/mpc_1.3.1_arm64-linux-gnu_prebuilt.tar.zst",
              sha256 = "53bde157437bdd32c2502952e327a902982000acc136312487b9cb7179652cab",
              extract = true,
            } | Source,
        } target,
      ],
      outputs = {
        usr = { glob = "usr/**/*" } | OutputLib,
      },
    } | BuildSpec,
} | BuildSpec
