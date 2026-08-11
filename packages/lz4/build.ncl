let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let tar = import "../tar/build.ncl" in
let make = import "../make/build.ncl" in
let sed = import "../sed/build.ncl" in
let grep = import "../grep/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let diffutils = import "../diffutils/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let glibc = import "../glibc/build.ncl" in

let version = "1.10.0" in
{
  name = "lz4",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/lz4-%{version}.tar.gz",
      sha256 = "537512904744b35e232912055ccf8ec66d768639ff3abe5788d90d792ec5f48b"
    } | Source,
    bash-bootstrap,
    tar,
    make,
    sed,
    grep,
    coreutils,
    diffutils,
    toolchain,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  outputs = {
    lz4 = { glob = "usr/bin/lz4" } | OutputBin,
    lz4c = { glob = "usr/bin/lz4c" } | OutputBin,
    lz4cat = { glob = "usr/bin/lz4cat" } | OutputBin,
    unlz4 = { glob = "usr/bin/unlz4" } | OutputBin,

    liblz4 = { glob = "usr/lib/liblz4.so*" } | OutputLib,

    pkgconfigs = { glob = "usr/lib/pkgconfig/**" } | OutputData,

    mans = { glob = "usr/share/man/**" } | OutputData,
    includes = { glob = "usr/include/**" } | OutputData,
  },

  replace_on_cycle =
    {
      name = "lz4 (prebuilt)",
      prebuilt = true,
      build_deps = [
        match {
          { arch = 'Amd64, .. } =>
            {
              url = "gs://minimal-staging-archives/prebuilts/lz4/fbd8d1e9a8c1cb2987f8264b4b86466e4e6c185cae545f5ab5f4f40a45525730.tar.zst",
              sha256 = "e346a414f9ce3fcbd0d190aa835c9bc5881019919f4dcbb99e4e661cb9c77b34",
              extract = true,
            } | Source,
          { arch = 'Arm64, .. } =>
            {
              # BEDROCK ROOT: built from source by stage0-lz4-arm on our hex0-rooted toolchain.
              # GATED slot-compare vs the foreign slot -> SLOT_SUPERSET (delivers everything
              # the foreign tarball did). That check compares SLOT CONTENTS, not declared
              # outputs, because materialize_prebuilt ships a prebuilt whole and a declared-
              # output check therefore cannot see a removal.
              # GENERATION 1: compiled in a sandbox populated by foreign prebuilts. Output is
              # from source; foreign packages are BUILD INPUTS and appear in provenance.
              url = "gs://minimalmertic-hermetic-mirror/sha256/1454e18e375516d6820bfe10f8dce56ba4fda859aadd7a38f78060d69e6e617e/stage0-lz4-arm-aarch64.tar.zst",
              sha256 = "1454e18e375516d6820bfe10f8dce56ba4fda859aadd7a38f78060d69e6e617e",
              extract = true,
            } | Source,
        } target,
      ],
      outputs = {
        lz4 = { glob = "usr/bin/lz4" } | OutputBin,
        lz4c = { glob = "usr/bin/lz4c" } | OutputBin,
        lz4cat = { glob = "usr/bin/lz4cat" } | OutputBin,
        unlz4 = { glob = "usr/bin/unlz4" } | OutputBin,
        liblz4 = { glob = "usr/lib/liblz4.so*" } | OutputLib,
        pkgconfigs = { glob = "usr/lib/pkgconfig/**" } | OutputData,
        mans = { glob = "usr/share/man/**" } | OutputData,
        includes = { glob = "usr/include/**" } | OutputData,
      },
    } | BuildSpec,
  attrs =
    {
      upstream_version = version,
      license_spdx = "BSD-2-Clause AND GPL-2.0-or-later",
      source_provenance = {
        category = 'GithubRepo,
        owner = "lz4",
        repo = "lz4",
      },
    } | Attrs,
} | BuildSpec
