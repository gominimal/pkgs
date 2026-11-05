# Versioned, PREFIXED LLVM lines (llvm-22, llvm-23, ...): the shared build plumbing
# (sources, deps, outputs, build script). Each llvm-<major>/build.ncl calls this and
# writes its own `{ ... } | BuildSpec` record with its attrs and tests in plain text,
# where license-lint, the smoke-test report and pkgmgr's regex tier read them.
#
# Same build as ../llvm (projects, targets, reproducibility flags), with two differences:
#   - everything installs under /usr/lib/llvm-<major>, so a prefixed line can share a
#     closure with the unprefixed llvm / llvm-bootstrap without a path collision (the
#     sandbox resolves a path present in two deps silently: lowest spec hash wins);
#   - binaries find their libLLVM/libclang through LLVM's default $ORIGIN/../lib RPATH
#     (../llvm skips the install RPATH because it lives in /usr/lib).
# Consumers point at the prefix explicitly (e.g. -DLLVM_DIR=/usr/lib/llvm-22/lib/cmake/llvm,
# /usr/lib/llvm-22/bin/clang). Built by the unchanged llvm-bootstrap: LLVM 22/23 keep the
# same host-toolchain minimums as 21 (GCC 7.4 / Clang 5.0, CMake 3.20).
#
# Upstream ships only the monorepo tarball for these releases (no per-project tarballs),
# with a sigstore attestation (<tarball>.jsonl) and a GPG signature (<tarball>.sig).
let { subsetOf, Local, OutputBin, OutputData, OutputLib, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let cmake = import "../cmake/build.ncl" in
let coreutils = import "../coreutils/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let libffi = import "../libffi/build.ncl" in
let llvm-bootstrap = import "../llvm-bootstrap/build.ncl" in
let ninja = import "../ninja/build.ncl" in
let python = import "../python/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let zlib = import "../zlib/build.ncl" in
fun llvm_version llvm_sha256 =>
  let llvm_major = std.array.first (std.string.split "." llvm_version) in
  let rel = "usr/lib/llvm-%{llvm_major}" in
  {
    name = "llvm-%{llvm_major}",
    major = llvm_major,
    prefix = "/%{rel}",
    build_deps = [
      { file = "versioned-build.sh" } | Local,
      {
        url = "https://github.com/llvm/llvm-project/releases/download/llvmorg-%{llvm_version}/llvm-project-%{llvm_version}.src.tar.xz",
        sha256 = llvm_sha256,
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

    cmd = "./versioned-build.sh",
    build_args = {
      version = llvm_version,
      major = llvm_major,
    },
    outputs = {
      bins = { glob = "%{rel}/bin/*" } | OutputBin,
      libexec = { glob = "%{rel}/libexec/**" } | OutputBin,
      libs = { glob = "%{rel}/lib/**", allow_data = true } | OutputLib,
      includes = { glob = "%{rel}/include/**" } | OutputData,
      share = { glob = "%{rel}/share/**" } | OutputData,
    },
  }
