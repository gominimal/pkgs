# pkgmgr: bootstrap_rung = "rust"
let { subsetOf, Attrs, BuildSpec, OutputData, Source, Test, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let base = import "../base/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let libffi = import "../libffi/build.ncl" in
let libssh2 = import "../libssh2/build.ncl" in
# LLVM 23, prefixed under /usr/lib/llvm-23. Pinned to the versioned line, not the default `llvm`
# (also 23.1.5 today), so the next default-LLVM major does not move this frozen rung.
let llvm-23 = import "../llvm-23/build.ncl" in
let openssl-3-5 = import "../openssl-3.5/build.ncl" in
let sqlite = import "../sqlite/build.ncl" in
let zlib = import "../zlib/build.ncl" in
# rustc-1.99.1: the stage0 for `rust`, from gen-16 of gominimal/bootstrap: the top of the Rust ladder,
# mrustc 0.12.0 (C++, built by the hex0-rooted gcc) -> mrustc-rustc-1.90.0 -> rustc-1.91.1 -> 1.92.0
# -> 1.93.1 -> 1.94.1 -> 1.95.0 -> 1.96.0 -> 1.97.1 -> 1.98.1 -> 1.99.1, every rung built on the
# hex0-rooted toolchain; this one is the first built against LLVM 23 (bootstrap's llvm-23) instead of
# LLVM 21. Installs the whole toolchain at /usr/lib/rustc-1.99.1 (bin/ + lib/); nothing lands on
# /usr/bin.
#
# TODO(gen-16): fill from tools/gen1-manifest.py output. gen-16 is NOT published yet: both
# sha256 values below are all-zero PLACEHOLDERS and the file names follow gen-13's naming
# (tools/gen-publish.py: <pkg>-<version>-<arch>.tar.zst, or <pkg>-<arch> when the manifest has
# no version for that arch). Replace url and sha256 together from generations/gen-16/MANIFEST.txt.
let version = "1.99.1" in
let amd64_sha256 = "0000000000000000000000000000000000000000000000000000000000000000" in # TODO(gen-16): fill from tools/gen1-manifest.py output
let arm64_sha256 = "0000000000000000000000000000000000000000000000000000000000000000" in # TODO(gen-16): fill from tools/gen1-manifest.py output
{
  name = "rustc-1.99.1",
  prebuilt = true,
  build_deps = [
    match {
      { arch = 'Amd64, .. } =>
        {
          url = "gs://minimal-bootstrap/gen-16/sha256/%{amd64_sha256}/rustc-1.99.1-1.99.1-x86_64.tar.zst",
          sha256 = amd64_sha256,
          extract = true,
        } | Source,
      { arch = 'Arm64, .. } =>
        {
          url = "gs://minimal-bootstrap/gen-16/sha256/%{arm64_sha256}/rustc-1.99.1-aarch64.tar.zst",
          sha256 = arm64_sha256,
          extract = true,
        } | Source,
    } target,
  ],
  # librustc_driver loads libLLVM.so.23.1 at run time (built `host-llvm: external, link-shared`,
  # no RUNPATH), from the frozen, prefixed `llvm-23` (/usr/lib/llvm-23/lib, reached through the
  # LD_LIBRARY_PATH its consumers export when the default llvm is not 23) rather than the default
  # `llvm`, whose major will move past 23; cargo links libssh2, libssl.so.3 (openssl-3.5, the
  # ladder's openssl line), libz and libsqlite3; the binaries run on the standard loader.
  # TODO(gen-16): confirm this list against the published rung's DT_NEEDED.
  runtime_deps = [
    libffi,
    libssh2,
    llvm-23,
    openssl-3-5,
    sqlite,
    zlib,
    subsetOf gcc ["libgcc", "libstdcpp"],
  ],
  # the binary runs from its own runtime closure, outside any build sandbox; libLLVM.so.23.1 is
  # under llvm-23's prefix, which only the environment can name (see runtime_deps above)
  tests = {
    rustc_version =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [["/bin/sh", "-c", "LD_LIBRARY_PATH=/usr/lib/llvm-23/lib /usr/lib/rustc-1.99.1/bin/rustc -vV"]],
      } | Test,
  },
  outputs = {
    toolchain = { glob = "usr/lib/rustc-1.99.1/**", allow_executable = true } | OutputData,
  },
  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT OR Apache-2.0",
      source_provenance = {
        category = 'GithubRepo,
        owner = "rust-lang",
        repo = "rust",
      },
    } | Attrs,
} | BuildSpec
