let { standaloneTest, Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
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
              # gominimal/bootstrap gen-11 object (generations/gen-11/manifest.json)
              url = "gs://minimal-bootstrap/gen-11/sha256/af6e9e6f6e68730c37025ef2753f6cecf5679e6f01d26e5e4d7a9f69cb3c00be/lz4-x86_64.tar.zst",
              sha256 = "af6e9e6f6e68730c37025ef2753f6cecf5679e6f01d26e5e4d7a9f69cb3c00be",
              extract = true,
            } | Source,
          { arch = 'Arm64, .. } =>
            {
              # gominimal/bootstrap gen-11 object (generations/gen-11/manifest.json)
              url = "gs://minimal-bootstrap/gen-11/sha256/7a2bca4b6d4d263eaf3815b5c8660f83393ccc83c12ec34a2b8e7cdaec81cab1/lz4-aarch64.tar.zst",
              sha256 = "7a2bca4b6d4d263eaf3815b5c8660f83393ccc83c12ec34a2b8e7cdaec81cab1",
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

  tests = {
    smoketest = standaloneTest "/usr/bin/lz4 --version",
  },
} | BuildSpec
