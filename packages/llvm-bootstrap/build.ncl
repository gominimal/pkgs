let { subsetOf, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let ninja = import "../ninja/build.ncl" in
let python = import "../python/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let zlib = import "../zlib/build.ncl" in
let version = "21.1.8" in

{
  name = "llvm-bootstrap",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "gs://minimal-staging-archives/clang-%{version}.src.tar.xz",
      sha256 = "6090e3f23720d003cdd84483a47d0eec6d01adbb5e0c714ac0c8b58de546aa62"
    } | Source,
    {
      url = "gs://minimal-staging-archives/cmake-%{version}.src.tar.xz",
      sha256 = "85735f20fd8c81ecb0a09abb0c267018475420e93b65050cc5b7634eab744de9"
    } | Source,
    {
      url = "gs://minimal-staging-archives/lld-%{version}.src.tar.xz",
      sha256 = "d9524c5ee952500a2af92c27042a0d90ab089962af47816d4c85d0ebf76373d1"
    } | Source,
    {
      url = "gs://minimal-staging-archives/libunwind-%{version}.src.tar.xz",
      sha256 = "03e8adc6c3bdde657dcaedc94886ea70d1f7d551d622fcd8a36a8300e5c36cbc"
    } | Source,
    {
      url = "gs://minimal-staging-archives/llvm-%{version}.src.tar.xz",
      sha256 = "d9022ddadb40a15015f6b27e6549a7144704ded8828ba036ffe4b8165707de21"
    } | Source,
    {
      url = "gs://minimal-staging-archives/third-party-%{version}.src.tar.xz",
      sha256 = "7fe99424384aea529ffaeec9cc9dfb8b451fd1852c03fc109e426fe208a1f1a7"
    } | Source,
    base,
    cmake,
    ninja,
    python,
    toolchain,
  ],
  runtime_deps = [
    glibc,
    subsetOf gcc ["libgcc"],
    zlib,
  ],

  cmd = "./build.sh",
  outputs = {
    bins = { glob = "usr/bin/*" } | OutputBin,
    libs = { glob = "usr/lib/*.{so*,a}" } | OutputLib,
    libs_clang = { glob = "usr/lib/clang/*/**", allow_data = true } | OutputLib,
    libexec = { glob = "usr/libexec/**" } | OutputBin,
    cmake_data_llvm = { glob = "usr/lib/cmake/llvm/*.cmake" } | OutputData,
    cmake_data_clang = { glob = "usr/lib/cmake/clang/*.cmake" } | OutputData,
    includes = { glob = "usr/include/**" } | OutputData,
  },

  attrs = {
    upstream_version = version,
    build_cost_multiple = 6,
  },
} | BuildSpec
