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
              # BEDROCK ROOT: this artifact is built by the hex0-rooted bootstrap ladder and
              # replaces the previous prebuilt in this slot. Provenance, seals, and evidence:
              # gominimal/minimermetic#16. Applied by minimermetic's
              # bin/queue/update-bedrock-roots.py from its bedrock-roots-manifest.txt.
              url = "gs://minimal-staging-archives/prebuilts/bedrock/sha256/1419ad928f9d9f9324f34f4b891093dd982faa2abef669ce1e3bed653fc5814d/stage0-lz4-amd-x86_64.tar.zst",
              sha256 = "1419ad928f9d9f9324f34f4b891093dd982faa2abef669ce1e3bed653fc5814d",
              extract = true,
            } | Source,
          { arch = 'Arm64, .. } =>
            {
              # BEDROCK ROOT: this artifact is built by the hex0-rooted bootstrap ladder and
              # replaces the previous prebuilt in this slot. Provenance, seals, and evidence:
              # gominimal/minimermetic#16. Applied by minimermetic's
              # bin/queue/update-bedrock-roots.py from its bedrock-roots-manifest.txt.
              url = "gs://minimal-staging-archives/prebuilts/bedrock/sha256/1454e18e375516d6820bfe10f8dce56ba4fda859aadd7a38f78060d69e6e617e/stage0-lz4-arm-aarch64.tar.zst",
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
