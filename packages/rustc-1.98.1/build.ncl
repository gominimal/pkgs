let { subsetOf, Attrs, BuildSpec, OutputData, Source, .. } = import "minimal.ncl" in
let { target, .. } = import "config.ncl" in
let gcc = import "../gcc/build.ncl" in
let libffi = import "../libffi/build.ncl" in
let libssh2 = import "../libssh2/build.ncl" in
let llvm = import "../llvm/build.ncl" in
let openssl-3-5 = import "../openssl-3.5/build.ncl" in
let sqlite = import "../sqlite/build.ncl" in
let zlib = import "../zlib/build.ncl" in
# rustc-1.98.1: the stage0 for `rust`, from gen-11 of gominimal/bootstrap: the top of the Rust ladder,
# mrustc 0.12.0 (C++, built by the hex0-rooted gcc) -> mrustc-rustc-1.90.0 -> rustc-1.91.1 -> 1.92.0
# -> 1.93.1 -> 1.94.1 -> 1.95.0 -> 1.96.0 -> 1.97.1 -> 1.98.1, every rung built on the hex0-rooted
# toolchain and this one reproduced byte for byte on two independent machines per arch before
# publishing (generations/gen-11/manifest.json). Installs the whole toolchain at /usr/lib/rustc-1.98.1
# (bin/ + lib/); nothing lands on /usr/bin.
let version = "1.98.1" in
{
  name = "rustc-1.98.1",
  prebuilt = true,
  build_deps = [
    match {
      { arch = 'Amd64, .. } =>
        {
          url = "gs://minimal-bootstrap/gen-11/sha256/703e379bc5f86b94977e8c88f544a3e269c35d573c7daff555a6d43da29ea9f4/rustc-1.98.1-1.98.1-x86_64.tar.zst",
          sha256 = "703e379bc5f86b94977e8c88f544a3e269c35d573c7daff555a6d43da29ea9f4",
          extract = true,
        } | Source,
      { arch = 'Arm64, .. } =>
        {
          url = "gs://minimal-bootstrap/gen-11/sha256/edaa5fd0b164cf9ceb20d8315fe9dac59ea0b4e7f324ebf2eab6746e06c29c9a/rustc-1.98.1-aarch64.tar.zst",
          sha256 = "edaa5fd0b164cf9ceb20d8315fe9dac59ea0b4e7f324ebf2eab6746e06c29c9a",
          extract = true,
        } | Source,
    } target,
  ],
  # librustc_driver loads the live llvm's libLLVM.so.21.1 (built `host-llvm: external, link-shared`,
  # so an llvm soname bump needs a new generation); cargo links libssh2, libssl.so.3 (openssl-3.5,
  # the ladder's openssl line), libz and libsqlite3; the binaries run on the standard loader
  runtime_deps = [
    libffi,
    libssh2,
    llvm,
    openssl-3-5,
    sqlite,
    zlib,
    subsetOf gcc ["libgcc", "libstdcpp"],
  ],
  outputs = {
    toolchain = { glob = "usr/lib/rustc-1.98.1/**", allow_executable = true } | OutputData,
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
