let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
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
        match {
          { arch = 'Amd64, .. } =>
            {
              url = "gs://minimal-staging-archives/prebuilts/zlib/b9d37702ffc6dd16207c56f16aa42425084528c9e20e2748478e16fa4607a443.tar.zst",
              sha256 = "d80130aebaa9ecf50e382616d84423afead445271455c41f06eaffc75777dc6c",
              extract = true,
            } | Source,
          { arch = 'Arm64, .. } =>
            {
              url = "gs://minimal-staging-archives/prebuilts/zlib/arm64-linux-gnu/zlib_1.3.1_arm64-linux-gnu_prebuilt.tar.zst",
              sha256 = "cfc9bd997715f85c996772d07cb500084d12ca41d9a0dcb8b3feae8b1f1e6023",
              extract = true,
            } | Source,
        } target,
      ],
      outputs = {
        libz = { glob = "usr/lib/libz.so*" } | OutputLib,
        zconf_h = { glob = "usr/include/zconf.h" } | OutputData,
        zlib_h = { glob = "usr/include/zlib.h" } | OutputData,
        pkgconfig = { glob = "usr/lib/pkgconfig/zlib.pc" } | OutputData,
      },
    } | BuildSpec,
  attrs =
    {
      source_provenance = {
        category = 'GithubRepo,
        owner = "madler",
        repo = "zlib",
      },
    } | Attrs,
} | BuildSpec
