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
              # BEDROCK ROOT: this artifact is built by the hex0-rooted bootstrap ladder and
              # replaces the previous prebuilt in this slot. Provenance, seals, and evidence:
              # gominimal/minimermetic#16. Applied by minimermetic's
              # bin/queue/update-bedrock-roots.py from its bedrock-roots-manifest.txt.
              url = "gs://minimal-staging-archives/prebuilts/bedrock/sha256/717d2671877766c03338838d2072f4b3db719827f387fa7ade4daf74d13083ab/stage0-zlib-amd-x86_64.tar.zst",
              sha256 = "717d2671877766c03338838d2072f4b3db719827f387fa7ade4daf74d13083ab",
              extract = true,
            } | Source,
          { arch = 'Arm64, .. } =>
            {
              # BEDROCK ROOT: this artifact is built by the hex0-rooted bootstrap ladder and
              # replaces the previous prebuilt in this slot. Provenance, seals, and evidence:
              # gominimal/minimermetic#16. Applied by minimermetic's
              # bin/queue/update-bedrock-roots.py from its bedrock-roots-manifest.txt.
              url = "gs://minimal-staging-archives/prebuilts/bedrock/sha256/d3b6f8f598e48ff5e8a062b3a65fa97fcbd895ddb173cfe9bde0ee855c783d4a/stage0-zlib-arm-aarch64.tar.zst",
              sha256 = "d3b6f8f598e48ff5e8a062b3a65fa97fcbd895ddb173cfe9bde0ee855c783d4a",
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
