let { BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let make = import "../make/build.ncl" in
let python = import "../python/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let gcc = import "../gcc/build.ncl" in

let version = "4.16.0" in
{
  name = "z3",

  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/Z3Prover/z3/archive/refs/tags/z3-%{version}.tar.gz",
      sha256 = "c68c3e5e4810b16126b8cb4c47eee85c1ac3e24a81914c8e371b40de9dd33ac7",
      extract = true,
      strip_prefix = "z3-z3-%{version}",
    } | Source,
    base,
    cmake,
    make,
    python,
    toolchain,
  ],

  runtime_deps = [
    glibc,
    gcc,
  ],

  cmd = "./build.sh",

  outputs = {
    bins = { glob = "usr/bin/z3" } | OutputBin,
    libs = { glob = "usr/lib/libz3.so*" } | OutputLib,
    includes = { glob = "usr/include/**" } | OutputData,
    pkgconfig = { glob = "usr/lib/pkgconfig/z3.pc" } | OutputData,
    cmake_data = { glob = "usr/lib/cmake/z3/**" } | OutputData,
  },

  attrs = {
    upstream_version = version,
    source_provenance = {
      category = 'GithubRepo,
      owner = "Z3Prover",
      repo = "z3",
    },
    build_cost_multiple = 3,
  },

  tests = {
    version_check =
      {
        class = 'Standalone,
        test_deps = [],
        cmds = [["z3", "--version"]],
      } | Test,
  },
} | BuildSpec
