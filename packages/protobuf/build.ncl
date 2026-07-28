let { subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let ninja = import "../ninja/build.ncl" in

let abseil-cpp = import "../abseil-cpp/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let zlib = import "../zlib/build.ncl" in

let version = "35.1" in
{
  name = "protobuf",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/protocolbuffers/protobuf/releases/download/v%{version}/protobuf-%{version}.tar.gz",
      sha256 = "f0b6838e7522a8da96126d487068c959bc624926368f3024ac8fd03abd0a1ac4",
      extract = true,
      strip_prefix = "protobuf-%{version}",
    } | Source,
    base,
    make,
    cmake,
    ninja,
    toolchain,
  ],
  runtime_deps = [
    glibc,
    abseil-cpp,
    subsetOf gcc ["libgcc", "libstdcpp"],
    zlib,
  ],

  cmd = "./build.sh",
  outputs = {
    bins = { glob = "usr/bin/*" } | OutputBin,

    libprotobuf = { glob = "usr/lib/libprotobuf*.so*" } | OutputLib,
    libprotoc = { glob = "usr/lib/libprotoc*.so*" } | OutputLib,
    libupb = { glob = "usr/lib/libupb{.a,*.so*}" } | OutputLib,
    libutf8 = { glob = "usr/lib/libutf8*.so*" } | OutputLib,

    includes = { glob = "usr/include/**" } | OutputData,
    cmake_data = { glob = "usr/lib/cmake/**" } | OutputData,
    pkgconfigs = { glob = "usr/lib/pkgconfig/*.pc" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "BSD-3-Clause",
      source_provenance = {
        category = 'GithubRepo,
        owner = "protocolbuffers",
        repo = "protobuf",
      },
    } | Attrs,
} | BuildSpec
