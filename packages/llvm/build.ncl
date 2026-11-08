let { subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let libffi = import "../libffi/build.ncl" in
let llvm-bootstrap = import "../llvm-bootstrap/build.ncl" in
let ninja = import "../ninja/build.ncl" in
let python = import "../python/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let zlib = import "../zlib/build.ncl" in
let version = "23.1.5" in

# The default, UNPREFIXED LLVM (/usr/bin/clang, /usr/lib/libLLVM.so.23.1, ...). Consumers
# that must stay on an older major use the prefixed lines instead (llvm-21: the Rust ladder
# rungs, emscripten and bun; llvm-22: zig, odin), which live under /usr/lib/llvm-<major> so
# they can share a closure with this package. Built by llvm-bootstrap (LLVM 21, built by
# gcc): LLVM 23 needs a GCC 7.4 / Clang 5.0 host and CMake 3.20, same as 21.
{
  name = "llvm",
  build_deps = [
    { file = "build.sh" } | Local,
    # Upstream stopped publishing per-project tarballs after 21.x (22.x and 23.x ship
    # only the monorepo tarball, with a sigstore attestation from release-sources.yml),
    # so this is the same source the prefixed llvm-22 / llvm-23 lines use.
    {
      url = "https://github.com/llvm/llvm-project/releases/download/llvmorg-%{version}/llvm-project-%{version}.src.tar.xz",
      sha256 = "fb50b1eac93ddeb3aa8dab4cfe324dff74f4a9c2bdee6160c9e36188f8d06a6e",
    } | Source,
    base,
    cmake,
    llvm-bootstrap,
    ninja,
    python,
    toolchain,
  ],
  runtime_deps = [
    coreutils, # For /usr/bin/env
    glibc,
    libffi,
    zlib,
    subsetOf gcc ["libgcc", "libstdcpp"],
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
  },
  outputs = {
    bins = { glob = "usr/bin/*" } | OutputBin,
    clangd = { glob = "usr/bin/clangd" } | OutputBin,

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
  tests = {
    versions =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "/usr/bin/clang --version | grep -F 'clang version %{version}'"],
          ["/bin/bash", "-c", "test \"$(/usr/bin/llvm-config --version)\" = %{version}"],
          ["/bin/bash", "-c", "/usr/bin/ld.lld --version | grep -F 'LLD %{version}'"],
        ],
      } | Test,
    hello_clang_lld =
      {
        class = 'Standalone,
        test_deps = [base, glibc, gcc],
        cmds = [
          ["/bin/bash", "-c", "printf '#include <stdio.h>\\nint main(void){puts(\"hello llvm\");return 0;}\\n' > hello.c"],
          ["/usr/bin/clang", "-fuse-ld=lld", "hello.c", "-o", "hello"],
          ["/bin/bash", "-c", "./hello | grep -qx 'hello llvm'"],
        ],
      } | Test,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "Apache-2.0",
      source_provenance = {
        category = 'GithubRepo,
        owner = "llvm",
        repo = "llvm-project",
      },
      build_cost_multiple = 6,
    } | Attrs,
} | BuildSpec
