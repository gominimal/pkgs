let { BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
# base
let bash = import "../bash/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let diffutils = import "../diffutils/build.ncl" in
let grep = import "../grep/build.ncl" in
let file = import "../file/build.ncl" in
let make = import "../make/build.ncl" in
let sed = import "../sed/build.ncl" in
# toolchain
let binutils = import "../binutils/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let linux_headers = import "../linux_headers/build.ncl" in

let zlib = import "../zlib/build.ncl" in

let glibc = import "../glibc/build.ncl" in
let lz4 = import "../lz4/build.ncl" in
let xz = import "../xz/build.ncl" in

let version = "1.5.7" in
{
  name = "zstd",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/zstd-%{version}.tar.gz",
      sha256 = "eb33e51f49a15e023950cd7825ca74a4a2b43db8354825ac24fc1b7ee09e6fa3",
      extract = true,
      strip_prefix = "zstd-%{version}",
    } | Source,
    bash,
    coreutils,
    diffutils,
    file,
    sed,
    grep,
    make,
    binutils,
    gcc,
    linux_headers,
    zlib,
  ],
  runtime_deps = [
    glibc,
    lz4,
    xz,
  ],

  cmd = "./build.sh",

  outputs = {
    zstd_bin = { glob = "usr/bin/zstd" } | OutputBin,
    zstdcat = { glob = "usr/bin/zstdcat" } | OutputBin,
    zstdgrep = { glob = "usr/bin/zstdgrep" } | OutputBin,
    zstdless = { glob = "usr/bin/zstdless" } | OutputBin,
    zstdmt = { glob = "usr/bin/zstdmt" } | OutputBin,
    unzstd = { glob = "usr/bin/unzstd" } | OutputBin,

    libzstd = { glob = "usr/lib/libzstd.{so*,la}" } | OutputLib,

    includes = { glob = "usr/include/**" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
  },

  replace_on_cycle =
    {
      name = "zstd (prebuilt)",
      prebuilt = true,
      inputs = [
        {
          url = "gs://minimal-staging-archives/prebuilts/zstd/arm64-linux-gnu/zstd_1.5.6_arm64-linux-gnu_prebuilt.tar.zst",
          sha256 = "351407a5d2c8541f0758143fe4901aa3ba1e0a0a876b697289eb295749b3fda1",
          extract = true,
        } | Source,
      ],
      outputs = {
        zstd_bin = { glob = "usr/bin/zstd" } | OutputLib,
        zstdcat = { glob = "usr/bin/zstdcat" } | OutputLib,
        zstdgrep = { glob = "usr/bin/zstdgrep" } | OutputLib,
        zstdless = { glob = "usr/bin/zstdless" } | OutputLib,
        zstdmt = { glob = "usr/bin/zstdmt" } | OutputLib,
        unzstd = { glob = "usr/bin/unzstd" } | OutputLib,
        libzstd = { glob = "usr/lib/libzstd.so*" } | OutputLib,
        libzstd_a = { glob = "usr/lib/libzstd.a" } | OutputLib,
        headers = { glob = "usr/include/*.h" } | OutputLib,
        pkgconfig = { glob = "usr/lib/pkgconfig/libzstd.pc" } | OutputLib,
      },
    } | BuildSpec,
} | BuildSpec
