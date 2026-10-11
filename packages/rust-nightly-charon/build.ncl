# The pinned nightly Rust toolchain WITH `rustc-dev` that AeneasVerif/charon
# needs (`rust-toolchain.toml` → nightly-2026-06-01 + rustc-dev/rust-src). charon
# is a `rustc_private` tool: it links the compiler's internal crates
# (librustc_driver, …), so a normal stable `rust` won't do.
#
# This is a PREBUILT (binary) toolchain — we mirror the official
# `static.rust-lang.org/dist/2026-06-01/` component tarballs to gs:// and
# assemble a sysroot via each component's `install.sh`. A rustc-dev toolchain is
# a bootstrap tool (rustc's own build ships a binary stage0), so a from-source
# build buys nothing here; every tarball is pinned by sha256.
let { subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, OutputLib, Source, Test, .. } =
  import "minimal.ncl"
in
let { target, .. } = import "config.ncl" in
let base = import "../base/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let zlib = import "../zlib/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let date = "2026-09-17" in
# An arch-selected component tarball (raw — build.sh runs its install.sh).
let component = fun base_name amd64_sha arm64_sha =>
  (match {
    { arch = 'Amd64, .. } =>
      {
        url = "gs://minimal-staging-archives/%{base_name}-%{date}-x86_64-unknown-linux-gnu.tar.xz",
        sha256 = amd64_sha,
        extract = false,
      } | Source,
    { arch = 'Arm64, .. } =>
      {
        url = "gs://minimal-staging-archives/%{base_name}-%{date}-aarch64-unknown-linux-gnu.tar.xz",
        sha256 = arm64_sha,
        extract = false,
      } | Source,
  }
  ) target
in
{
  name = "rust-nightly-charon",
  build_deps = [
    { file = "build.sh" } | Local,
    # rustc + cargo + rust-std + rustc-dev, per-arch. rust-src is arch-independent.
    component
      "rustc-nightly"
      "6c4b66572411880b75f845892414e9b0ea04dfbbc50e0ce5394bd162c3e0dda6"
      "e9b1db78f180ea7805ba677a9cac85d464fef749f43fe9f4970d32c7bde6a06c",
    component
      "cargo-nightly"
      "155812325ded8f28460f91584a641b38ffb6292c1f7ba993c464376dd2e849af"
      "7eba15269abd35e3bf31749b7ddca8232fb37a38c24e3ca3dd7af717c6d05832",
    component
      "rust-std-nightly"
      "ce0462a1f0c3d6bf22fb952918a9840f1e85e6c1c3edd1d7840a90ab0a08dd8c"
      "a1e410947d61dd29d5d9978828cf9deca022788c1decbe2d0d8a826c01694f2b",
    component
      "rustc-dev-nightly"
      "53e753dcf3977aa70779320f6dc3819b94f50a0529ac54725cb2e496a6b7fccb"
      "683b2ec19437f4a975f67ed91bea4e6e470d7dcaeacbb1d7fb0ebc7495936374",
    {
      url = "gs://minimal-staging-archives/rust-src-nightly-%{date}.tar.xz",
      sha256 = "cd272bc7b901f15464a44cbae891c3c7fd1847d6309eb7546fbf785bcadc8d7c",
      extract = false,
    } | Source,
    base,
    toolchain,
  ],
  runtime_deps = [
    glibc,
    zlib,
    subsetOf gcc ["libgcc", "libstdcpp"],
  ],
  cmd = "./build.sh",
  outputs = {
    rustc = { glob = "usr/bin/rustc" } | OutputBin,
    cargo = { glob = "usr/bin/cargo" } | OutputBin,
    rustdoc = { glob = "usr/bin/rustdoc" } | OutputBin,
    # librustc_driver + the bundled libLLVM.so* rustc dynamically links (rustc's
    # RUNPATH is $ORIGIN/../lib). A narrow librustc_driver-only glob silently
    # dropped libLLVM → rustc exited 127 at runtime. Captured as OutputData (not
    # OutputLib) because libLLVM-22-*.so is a symlink to libLLVM.so.22.1-*, which
    # OutputLib's ELF validator rejects ("unknown file magic").
    libs = { glob = "usr/lib/*.so*", allow_executable = true } | OutputData,
    rustlib = { glob = "usr/lib/rustlib/**", allow_executable = true } | OutputData,
  },
  attrs =
    {
      upstream_version = "nightly-%{date}",
      license_spdx = "MIT OR Apache-2.0",
      source_provenance = {
        category = 'GithubRepo,
        owner = "rust-lang",
        repo = "rust",
      },
    } | Attrs,
  tests = {
    # The reason this package exists: prove the assembled toolchain can compile a
    # `rustc_private` crate — i.e. that rustc-dev's internal crates (rustc_driver,
    # rustc_interface, …) resolve against the sysroot. `--emit=metadata` type-checks
    # + resolves the extern crates without codegen/link, so no C linker is needed.
    rustc_private_resolves =
      {
        class = 'Standalone,
        test_deps = [base, glibc, zlib, gcc],
        cmds = [
          ["/usr/bin/rustc", "--version"],
          [
            "/bin/sh",
            "-c",
            "printf '#![feature(rustc_private)]\\nextern crate rustc_driver;\\nextern crate rustc_interface;\\nextern crate rustc_span;\\npub fn main() {}\\n' > /tmp/probe.rs && /usr/bin/rustc --edition 2021 --crate-type=lib --emit=metadata /tmp/probe.rs -o /tmp/probe.rmeta && echo RUSTC_PRIVATE_RESOLVES_OK",
          ],
        ],
      } | Test,
  },
} | BuildSpec
