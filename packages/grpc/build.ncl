let { subsetOf, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in

let version = "1.83.0" in

let base = import "../base/build.ncl" in
let binutils = import "../binutils/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let linux_headers = import "../linux_headers/build.ncl" in
let make = import "../make/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let abseil-cpp = import "../abseil-cpp/build.ncl" in
let c-ares = import "../c-ares/build.ncl" in
let openssl = import "../openssl/build.ncl" in
let protobuf = import "../protobuf/build.ncl" in
let re2 = import "../re2/build.ncl" in
let zlib = import "../zlib/build.ncl" in
let python = import "../python/build.ncl" in

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

  tests = {
    link_and_run = {
      class = 'Standalone,
      test_deps = [base, toolchain, binutils, linux_headers],
      cmds = [
        ["/bin/bash", "-c", "echo '#include <grpc/grpc.h>\nint main() { grpc_init(); grpc_shutdown(); return 0; }' > test.c"],
        ["/bin/gcc", "test.c", "-lgrpc", "-o", "test"],
        ["./test"],
      ],
    } | Test,
    plugin_check = {
      class = 'Standalone,
      test_deps = [base],
      cmds = [
        ["/bin/bash", "-c", "for p in cpp csharp node objective_c php python ruby; do command -v grpc_${p}_plugin > /dev/null || exit 1; done"],
      ],
    } | Test,
    proto_compile = {
      class = 'Standalone,
      test_deps = [base, toolchain, binutils, protobuf, python, linux_headers],
      cmds = [
        ["/bin/bash", "-c", "echo 'syntax = \"proto3\"; package test; service Echo { rpc Ping (Message) returns (Message) {} } message Message { string body = 1; }' > test.proto"],
        ["/bin/bash", "-c", "protoc --cpp_out=. test.proto"],
        ["/bin/bash", "-c", "for p in cpp csharp node objective_c php python ruby; do protoc --plugin=protoc-gen-grpc_${p}=$(command -v grpc_${p}_plugin) --grpc_${p}_out=. test.proto; done"],
        ["/bin/bash", "-c", "g++ -c test.pb.cc test.grpc.pb.cc -std=c++17"],
      ],
    } | Test,
  },
} | BuildSpec
