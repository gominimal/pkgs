let { subsetOf, Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in

let glibc = import "../glibc/build.ncl" in
let gcc = import "../gcc/build.ncl" in

let version = "0.3.34" in
{
  name = "openblas",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/OpenMathLib/OpenBLAS/v%{version}.tar.gz",
      sha256 = "cd7e129868320cc2d033afa920e31202dfe0b8066a5b66661900ccc0f197dfed",
      extract = true,
      strip_prefix = "OpenBLAS-%{version}",
    } | Source,
    base,
    make,
    toolchain,
  ],
  runtime_deps = [
    glibc,
    subsetOf gcc ["libs"],
  ],

  cmd = "./build.sh",
  outputs = {
    libs = { glob = "usr/lib/libopenblas*.{a,so*}" } | OutputLib,

    includes = { glob = "usr/include/**" } | OutputData,
    cmake_data = { glob = "usr/lib/cmake/openblas/*.cmake" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "BSD-3-Clause",
      repology_project = "openblas",
      source_provenance = {
        category = 'GithubRepo,
        owner = "OpenMathLib",
        repo = "OpenBLAS",
      },
      build_cost_multiple = 2,
    } | Attrs,
} | BuildSpec
