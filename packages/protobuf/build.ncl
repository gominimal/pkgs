let { subsetOf, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let make = import "../make/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let ninja = import "../ninja/build.ncl" in

let abseil-cpp = import "../abseil-cpp/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let zlib = import "../zlib/build.ncl" in
{
  name = "protobuf",
  inputs = [
    { file = "build.sh" } | Local,
    {
        url = "https://github.com/protocolbuffers/protobuf/releases/download/v32.0/protobuf-32.0.tar.gz",
        sha256 = "9dfdf08129f025a6c5802613b8ee1395044fecb71d38210ca59ecad283ef68bb",
        extract = true,
        strip_prefix = "protobuf-32.0",
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
} | BuildSpec
