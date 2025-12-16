let { BuildSpec, Local, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let lz4 = import "../lz4/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let zlib = import "../zlib/build.ncl" in

let version = "1.5.7" in
{
  name = "zstd",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/zstd-%{version}.tar.gz",
      sha256 = "eb33e51f49a15e023950cd7825ca74a4a2b43db8354825ac24fc1b7ee09e6fa3"
    } | Source,
    base,
    make,
    lz4,
    toolchain,
    zlib,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

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

  replace_on_cycle =
    {
      name = "zstd (prebuilt)",
      prebuilt = true,
      inputs = [
        {
          url = "gs://minimal-staging-archives/prebuilts/zstd/8a24bda7b914208fe12d01fb1fa05de91aa5f506496896e422b21c07f88e6540.tar.zst",
          sha256 = "360e8995e62f1928192c3057546f0205787879610268f5e192e6afa5cce97da9",
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
