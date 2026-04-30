let { subsetOf, Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base = import "../base/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let python = import "../python/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let bzip2 = import "../bzip2/build.ncl" in
let xz = import "../xz/build.ncl" in
let zstd = import "../zstd/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "1.91.0-1" in
{
  name = "boost",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/boost-%{version}-b2-nodocs.tar.xz",
      sha256 = "7334bb672b9c7aa135da88bcc3111a64a198be9a7d44eb5151d9248e7cfd43ef",
    } | Source,
    base,
    python,
    toolchain,
    bzip2,
    xz,
    zstd,
  ],
  runtime_deps = [
    subsetOf
      gcc
      (
        ["libgcc", "libstdcpp"]
        @ match {
          { arch = 'Amd64, .. } => ["libquadmath"],
          { arch = 'Arm64, .. } => [],
        } target
      ),
    subsetOf bzip2 ["libs"],
    subsetOf xz ["liblzma"],
    subsetOf zstd ["libzstd"],
    glibc,
  ],

  cmd = "./build.sh",

  outputs = {
    libs = { glob = "usr/lib/*" } | OutputLib,

    includes = { glob = "usr/include/boost/**" } | OutputData,
    cmake_data = { glob = "usr/lib/cmake/**/*" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "BSL-1.0",
      source_provenance = {
        category = 'GithubRepo,
        owner = "boostorg",
        repo = "boost",
      },
      build_cost_multiple = 2,
    } | Attrs,
} | BuildSpec
