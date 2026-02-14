let { BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let bash = import "../bash/build.ncl" in
let make = import "../make/build.ncl" in
let sed = import "../sed/build.ncl" in
let tar = import "../tar/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in
{
  name = "zlib",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/zlib-1.3.1.tar.gz",
      sha256 = "9a93b2b7dfdac77ceba5a558a580e74667dd6fede4585b91eefb60f03b72df23"
    } | Source,
    bash,
    make,
    sed,
    tar,
    coreutils,
    toolchain,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  outputs = {
    libz = { glob = "usr/lib/libz.so*" } | OutputLib,
    zconf_h = { glob = "usr/include/zconf.h" } | OutputData,
    zlib_h = { glob = "usr/include/zlib.h" } | OutputData,
    pkgconfig = { glob = "usr/lib/pkgconfig/zlib.pc" } | OutputData,
  },

  replace_on_cycle =
    {
      name = "zlib (prebuilt)",
      prebuilt = true,
      inputs = [
        {
          url = "gs://minimal-staging-archives/prebuilts/zlib/arm64-linux-gnu/zlib_1.3.1_arm64-linux-gnu_prebuilt.tar.zst",
          sha256 = "9fce8c3befffe54a2848ea92c8534aa3ec76326bed399be8bc2c1d00c833f8cb",
          extract = true,
        } | Source,
      ],
      outputs = {
        libz = { glob = "usr/lib/libz.so*" } | OutputLib,
        zconf_h = { glob = "usr/include/zconf.h" } | OutputData,
        zlib_h = { glob = "usr/include/zlib.h" } | OutputData,
        pkgconfig = { glob = "usr/lib/pkgconfig/zlib.pc" } | OutputData,
      },
    } | BuildSpec,
} | BuildSpec
