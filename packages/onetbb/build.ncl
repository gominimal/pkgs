let { subsetOf, Attrs, BuildSpec, Local, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let ninja = import "../ninja/build.ncl" in

let glibc = import "../glibc/build.ncl" in
let gcc = import "../gcc/build.ncl" in

let version = "2022.3.0" in
{
  name = "onetbb",
  inputs = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/uxlfoundation/oneTBB/v%{version}.tar.gz",
      sha256 = "01598a46c1162c27253a0de0236f520fd8ee8166e9ebb84a4243574f88e6e50a",
      extract = true,
      strip_prefix = "oneTBB-%{version}",
    } | Source,
    base,
    make,
    cmake,
    ninja,
    toolchain,
  ],
  runtime_deps = [
    glibc,
    subsetOf gcc ["libgcc", "libstdcpp"],
  ],

  cmd = "./build.sh",
  outputs = {
    libtbb = { glob = "usr/lib/libtbb*.so*" } | OutputLib,

    includes = { glob = "usr/include/**" } | OutputData,
    cmake_data = { glob = "usr/lib/cmake/TBB/*.cmake" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      repology_project = "onetbb",
    } | Attrs,
} | BuildSpec
