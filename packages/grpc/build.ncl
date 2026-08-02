let { subsetOf, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in

let version = "1.83.0" in

let base = import "../base/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let abseil-cpp = import "../abseil-cpp/build.ncl" in
let c-ares = import "../c-ares/build.ncl" in
let openssl = import "../openssl/build.ncl" in
let protobuf = import "../protobuf/build.ncl" in
let re2 = import "../re2/build.ncl" in
let zlib = import "../zlib/build.ncl" in

{
  name = "grpc",

  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/grpc/grpc/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "90d453393a9d41215df546103b10b33b9566df79cdf6f49dc67f6c4d044d090d",
      extract = true,
      strip_prefix = "grpc-%{version}",
    } | Source,
    base,
    toolchain,
    make,
    cmake,
    abseil-cpp,
    c-ares,
    openssl,
    protobuf,
    re2,
    zlib,
  ],

  runtime_deps = [
    glibc,
    subsetOf gcc ["libgcc", "libstdcpp"],
    abseil-cpp,
    c-ares,
    openssl,
    protobuf,
    re2,
    zlib,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    bins = { glob = "usr/bin/*" } | OutputBin,
    libs = { glob = "usr/lib/*.so*" } | OutputLib,
    headers = { glob = "usr/include/**" } | OutputData,
    cmake = { glob = "usr/lib/cmake/**" } | OutputData,
    pkgconfig = { glob = "usr/lib/pkgconfig/**" } | OutputData,
    roots = { glob = "usr/share/grpc/roots.pem" } | OutputData,
  },

  attrs = {
    upstream_version = version,
    source_provenance = {
      category = 'GithubRepo,
      owner = "grpc",
      repo = "grpc",
    },
  },
} | BuildSpec
