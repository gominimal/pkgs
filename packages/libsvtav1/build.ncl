let { standaloneTest, Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let make = import "../make/build.ncl" in
let nasm = import "../nasm/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "4.3.1" in
{
  name = "libsvtav1",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      # Upstream moved to GitHub ("The canonical URL for this project is at
      # https://github.com/AOMediaCodec/SVT-AV1"); GitLab stopped at v4.3.0 (same
      # commit, e3d63405), and v4.3.1 exists only on GitHub.
      url = "https://github.com/AOMediaCodec/SVT-AV1/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "ad94f481cb74821af183f37f4533fc52324b76ffbd98ec7723e282bab0cf9fc4",
      extract = true,
      strip_prefix = "SVT-AV1-%{version}",
    } | Source,
    base,
    toolchain,
    cmake,
    make,
    nasm,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    bins = { glob = "usr/bin/SvtAv1*" } | OutputBin,
    libs = { glob = "usr/lib/libSvtAv1*.so*" } | OutputLib,
    includes = { glob = "usr/include/svt-av1/**" } | OutputData,
    pkgconfig = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "(BSD-2-Clause AND BSD-3-Clause-Clear)",
      source_provenance = {
        category = 'GithubRepo,
        owner = "AOMediaCodec",
        repo = "SVT-AV1",
      },
    } | Attrs,

  tests = {
    smoketest = standaloneTest "/usr/bin/SvtAv1EncApp --version",
  },
} | BuildSpec
