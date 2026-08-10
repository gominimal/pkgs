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
              url = "gs://minimal-staging-archives/prebuilts/zlib/b9d37702ffc6dd16207c56f16aa42425084528c9e20e2748478e16fa4607a443.tar.zst",
              sha256 = "d80130aebaa9ecf50e382616d84423afead445271455c41f06eaffc75777dc6c",
              extract = true,
            } | Source,
          { arch = 'Arm64, .. } =>
            {
              # BEDROCK ROOT (aarch64): built from source by stage0-zlib-arm on the toolchain whose
              # gcc/binutils/glibc roots are our own hex0-rooted artifacts. 42 gcc invocations,
              # verified against THIS package's own output globs before repointing:
              #   usr/lib/libz.so*  -> libz.so, libz.so.1, libz.so.1.3.2
              #   usr/include/{zconf.h,zlib.h}   usr/lib/pkgconfig/zlib.pc
              # all present. That check matters because materialize_prebuilt returns before the
              # unmatched-glob check, so a missing declared output would fail SILENTLY later.
              #
              # ⚠️ VERSION CHANGE 1.3.1 -> 1.3.2 (the from-source recipe builds 1.3.2).
              # ⚠️ GENERATION 1: built in a sandbox populated by foreign prebuilts. The OUTPUT is
              # from source; the foreign packages are BUILD INPUTS and appear in provenance. Not
              # yet hex0-rooted. The close is a generation-2 rebuild + fixed-point check.
              url = "gs://minimalmertic-hermetic-mirror/sha256/dbea11e90298ad12fdcb030fa27c4430a5da8a83c8717b72a3ce4bf5625ecb8a/stage0-zlib-arm-aarch64.tar.zst",
              sha256 = "dbea11e90298ad12fdcb030fa27c4430a5da8a83c8717b72a3ce4bf5625ecb8a",
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
