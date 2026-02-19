let { subsetOf, Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in

let glibc = import "../glibc/build.ncl" in
let gcc = import "../gcc/build.ncl" in

let version = "0.3.31" in
{
  name = "openblas",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/OpenMathLib/OpenBLAS/v%{version}.tar.gz",
      sha256 = "6dd2a63ac9d32643b7cc636eab57bf4e57d0ed1fff926dfbc5d3d97f2d2be3a6",
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
      repology_project = "openblas",
      source_provenance = {
        category = 'GithubRepo,
        owner = "OpenMathLib",
        repo = "OpenBLAS",
      },
    } | Attrs,
} | BuildSpec
