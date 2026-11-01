let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let make = import "../make/build.ncl" in
let sed = import "../sed/build.ncl" in
let tar = import "../tar/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "1.3.2" in
{
  name = "zlib",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/zlib-%{version}.tar.gz",
      sha256 = "b99a0b86c0ba9360ec7e78c4f1e43b1cbdf1e6936c8fa0f6835c0cd694a495a1"
    } | Source,
    bash-bootstrap,
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
      build_deps = [
        match {
          { arch = 'Amd64, .. } =>
            {
              # gominimal/bootstrap gen-11 object (generations/gen-11/manifest.json)
              url = "gs://minimal-bootstrap/gen-11/sha256/caf05bdb8fd7b37b502130ed0bcb94d8d598a9124197d457a25286009b3808d5/zlib-x86_64.tar.zst",
              sha256 = "caf05bdb8fd7b37b502130ed0bcb94d8d598a9124197d457a25286009b3808d5",
              extract = true,
            } | Source,
          { arch = 'Arm64, .. } =>
            {
              # gominimal/bootstrap gen-11 object (generations/gen-11/manifest.json)
              url = "gs://minimal-bootstrap/gen-11/sha256/fadaa94a026f3891dc88b778f323a571b2c80440049ca88846d6c931adaee927/zlib-aarch64.tar.zst",
              sha256 = "fadaa94a026f3891dc88b778f323a571b2c80440049ca88846d6c931adaee927",
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
      upstream_version = version,
      license_spdx = "Zlib",
      source_provenance = {
        category = 'GithubRepo,
        owner = "madler",
        repo = "zlib",
      },
    } | Attrs,
} | BuildSpec
