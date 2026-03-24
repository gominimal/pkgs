let { subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let libffi = import "../libffi/build.ncl" in
let llvm-bootstrap = import "../llvm-bootstrap/build.ncl" in
let ninja = import "../ninja/build.ncl" in
let python = import "../python/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let zlib = import "../zlib/build.ncl" in
let version = "21.1.8" in

{
  name = "llvm",
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
      url = "gs://minimal-staging-archives/compiler-rt-%{version}.src.tar.xz",
      sha256 = "dd54ae21aee1780fac59445b51ebff601ad016b31ac3a7de3b21126fd3ccb229"
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
    llvm-bootstrap,
    ninja,
    python,
    toolchain,
  ],
  runtime_deps = [
    glibc,
    libffi,
    zlib,
    subsetOf gcc ["libgcc", "libstdcpp"],
  ],

  cmd = "./build.sh",
  outputs = {
    bins = { glob = "usr/bin/*" } | OutputBin,

    libllvm = { glob = "usr/lib/*LLVM*.{so*,a}" } | OutputLib,
    libear = { glob = "usr/lib/libear/**", allow_data = true } | OutputLib,
    liblto = { glob = "usr/lib/libLTO.so*" } | OutputLib,
    libremarks = { glob = "usr/lib/libRemarks.so*" } | OutputLib,
    libscanbuild = { glob = "usr/lib/libscanbuild/**", allow_data = true } | OutputLib,

    libclang = { glob = "usr/lib/libclang*.{so*,a}" } | OutputLib,
    liblld = { glob = "usr/lib/liblld*.{so*,a}" } | OutputLib,
    libs_clang = { glob = "usr/lib/clang/*/**", allow_data = true } | OutputLib,

    libexec = { glob = "usr/libexec/**" } | OutputBin,
    share_data = { glob = "usr/share/**" } | OutputData,

    cmake_data_llvm = { glob = "usr/lib/cmake/llvm/*.cmake" } | OutputData,
    cmake_data_clang = { glob = "usr/lib/cmake/clang/*.cmake" } | OutputData,
    cmake_data_lld = { glob = "usr/lib/cmake/lld/*.cmake" } | OutputData,
    include_lld = { glob = "usr/include/lld*/**" } | OutputData,

    mans = { glob = "usr/share/man/**" } | OutputData,
    includes = { glob = "usr/include/**" } | OutputData,
    include_clang = { glob = "usr/include/clang*/**" } | OutputData,
    include_llvm = { glob = "usr/include/llvm*/**" } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      source_provenance = {
        category = 'GithubRepo,
        owner = "llvm",
        repo = "llvm-project",
      },
      build_cost_multiple = 6,
    } | Attrs,
} | BuildSpec
