let { subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let bzip2 = import "../bzip2/build.ncl" in
let curl = import "../curl/build.ncl" in
let expat = import "../expat/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let libuv = import "../libuv/build.ncl" in
let openssl = import "../openssl/build.ncl" in
let xz = import "../xz/build.ncl" in
let zlib = import "../zlib/build.ncl" in
let zstd = import "../zstd/build.ncl" in

let version = "4.2.3" in
{
  name = "cmake",
  build_deps = [
    {
      url = "gs://minimal-staging-archives/Kitware/CMake/v%{version}.tar.gz",
      sha256 = "803186734800e1e8b2a242154ba1ed7bda4e77643e77e12477c71f3cdc7ede1d",
      extract = true,
      strip_prefix = "CMake-%{version}",
    } | Source,
    { file = "build.sh" } | Local,
    base,
    make,
    toolchain,
  ],
  runtime_deps = [
    bzip2,
    curl,
    expat,
    glibc,
    subsetOf gcc ["libgcc", "libstdcpp"],
    libuv,
    openssl,
    xz,
    zlib,
    zstd,
  ],

  cmd = "./build.sh",
  outputs = {
    cmake = { glob = "usr/bin/cmake" } | OutputBin,
    cpack = { glob = "usr/bin/cpack" } | OutputBin,
    ctest = { glob = "usr/bin/ctest" } | OutputBin,

    cmake_data = { glob = "usr/share/cmake-*/**" } | OutputData,

    aclocals = { glob = "usr/share/aclocal/*" } | OutputData,
    completions = { glob = "usr/share/bash-completion/**/*" } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      repology_project = "cmake",
      source_provenance = {
        category = 'GithubRepo,
        owner = "Kitware",
        repo = "CMake",
        releases = 'TagBased {},
      },
      build_cost_multiple = 2,
    } | Attrs,
} | BuildSpec
