let { Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in

let glibc = import "../glibc/build.ncl" in

# TODO: Needs fortran compiler for LAPACK to properly work.

let version = "0.3.30" in
{
  name = "openblas",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/OpenMathLib/OpenBLAS/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "27342cff518646afb4c2b976d809102e368957974c250a25ccc965e53063c95d",
      extract = true,
      strip_prefix = "OpenBLAS-%{version}",
    } | Source,
    base,
    make,
    toolchain,
  ],
  runtime_deps = [
    glibc,
  ],

  cmd = "./build.sh",
  outputs = {
    libs = { glob = "usr/lib/libopenblas*.{a,so*}" } | OutputLib,

    includes = { glob = "usr/include/**" } | OutputData,
    cmake_data = { glob = "usr/lib/cmake/openblas/*.cmake" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
  },

  attrs = {
    upstream_version = version,
    repology_project = "openblas",
  } | Attrs,
} | BuildSpec
