let { Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
# base
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
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
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/zstd-%{version}.tar.gz",
      sha256 = "eb33e51f49a15e023950cd7825ca74a4a2b43db8354825ac24fc1b7ee09e6fa3",
      extract = true,
      strip_prefix = "zstd-%{version}",
    } | Source,
    bash-bootstrap,
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
    # Technically bins like zstdless depend on /bin/sh, but its not practical to depend on bash at such a low level.
    # Disable the lint for now.
    zstd_bin = { glob = "usr/bin/zstd" } | OutputBin,
    zstdcat = { glob = "usr/bin/zstdcat" } | OutputBin,
    zstdgrep = { glob = "usr/bin/zstdgrep", allow_missing_interpreter = true } | OutputBin,
    zstdless = { glob = "usr/bin/zstdless", allow_missing_interpreter = true } | OutputBin,
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
      build_deps = [
        match {
          { arch = 'Amd64, .. } =>
            {
              # BEDROCK ROOT: this artifact is built by the hex0-rooted bootstrap ladder and
              # replaces the previous prebuilt in this slot. Provenance, seals, and evidence:
              # gominimal/minimermetic#16. Applied by minimermetic's
              # bin/queue/update-bedrock-roots.py from its bedrock-roots-manifest.txt.
              url = "gs://minimal-staging-archives/prebuilts/bedrock/sha256/8783fecd0b9fb5f25676200bf8b334e5f0b116d22e1e11c5ba5683b7cff994e8/stage0-zstd-amd-x86_64.tar.zst",
              sha256 = "8783fecd0b9fb5f25676200bf8b334e5f0b116d22e1e11c5ba5683b7cff994e8",
              extract = true,
            } | Source,
          { arch = 'Arm64, .. } =>
            {
              # BEDROCK ROOT: this artifact is built by the hex0-rooted bootstrap ladder and
              # replaces the previous prebuilt in this slot. Provenance, seals, and evidence:
              # gominimal/minimermetic#16. Applied by minimermetic's
              # bin/queue/update-bedrock-roots.py from its bedrock-roots-manifest.txt.
              url = "gs://minimal-staging-archives/prebuilts/bedrock/sha256/16c31660ce632a29747751a14a89664bb219e8e0d37fb1748a2c00393b3c1bb6/stage0-zstd-arm-aarch64.tar.zst",
              sha256 = "16c31660ce632a29747751a14a89664bb219e8e0d37fb1748a2c00393b3c1bb6",
              extract = true,
            } | Source,
        } target,
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
  attrs =
    {
      upstream_version = version,
      license_spdx = "BSD-3-Clause OR GPL-2.0-only",
      source_provenance = {
        category = 'GithubRepo,
        owner = "facebook",
        repo = "zstd",
      },
    } | Attrs,
} | BuildSpec
