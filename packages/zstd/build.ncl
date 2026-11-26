let { standaloneTest, Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
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

let version = "1.6.0" in
{
  name = "zstd",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      # 1.6.0 fixes CVE-2026-124851 (streaming decompression of malformed data
      # could expose uninitialized memory, facebook/zstd#5023). Mirrored from the
      # GitHub release asset; sha256 matches upstream's .sha256 and the .sig
      # verifies with the Zstandard Release Signing Key
      # 4EF4AC63455FC9F4545D9B7DEF8FE99528B52FFD (same key as 1.5.7).
      url = "gs://minimal-staging-archives/zstd-%{version}.tar.gz",
      sha256 = "2ba599ae2a257976278e7e71e998433a387bfd18aa7b78678229fd5d84f5e9b8",
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
    zlib,
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
              # gominimal/bootstrap gen-13 object (generations/gen-13/manifest.json)
              url = "gs://minimal-bootstrap/gen-13/sha256/a3f22da74c67ba47602502d9e4545956b75f1a491e8874887f8a2bcf1df6a265/zstd-x86_64.tar.zst",
              sha256 = "a3f22da74c67ba47602502d9e4545956b75f1a491e8874887f8a2bcf1df6a265",
              extract = true,
            } | Source,
          { arch = 'Arm64, .. } =>
            {
              # gominimal/bootstrap gen-13 object (generations/gen-13/manifest.json)
              url = "gs://minimal-bootstrap/gen-13/sha256/3c5bd1bd5734ab579f14f7bd6b07d8b9671eec545b49060bfbb47fa1c112ecd7/zstd-aarch64.tar.zst",
              sha256 = "3c5bd1bd5734ab579f14f7bd6b07d8b9671eec545b49060bfbb47fa1c112ecd7",
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

  tests = {
    smoketest = standaloneTest "/usr/bin/zstd --version",
  },
} | BuildSpec
