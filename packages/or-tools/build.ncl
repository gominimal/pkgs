let { subsetOf, Attrs, BuildSpec, Local, Needs, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let git = import "../git/build.ncl" in
let make = import "../make/build.ncl" in
let ninja = import "../ninja/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let zlib = import "../zlib/build.ncl" in

let version = "9.15" in
{
  name = "or-tools",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/google/or-tools/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "6395a00a97ff30af878ee8d7fd5ad0ab1c7844f7219182c6d71acbee1b5f3026",
      extract = true,
      strip_prefix = "or-tools-%{version}",
    } | Source,
    base,
    cmake,
    git,
    make,
    ninja,
    toolchain,
    zlib,
  ],
  runtime_deps = [
    glibc,
    subsetOf gcc ["libgcc", "libstdcpp"],
    zlib,
  ],

  needs =
    {
      dns = {},
      internet = {},
    } | Needs,

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    bins = { glob = "usr/bin/*" } | OutputBin,
    libortools = { glob = "usr/lib/libortools*.so*" } | OutputLib,
    libs = { glob = "usr/lib/lib*.so*" } | OutputLib,
    includes = { glob = "usr/include/**" } | OutputData,
    cmake_data = { glob = "usr/lib/cmake/**" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GithubRepo,
        owner = "google",
        repo = "or-tools",
      },
      build_cost_multiple = 2,
    } | Attrs,
} | BuildSpec
