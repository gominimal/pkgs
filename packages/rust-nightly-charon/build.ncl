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

let date = "2026-06-01" in
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
      "85e06d9b1091f2da0f924172be6861ce072e75ad86eaa6ec13d89e371c72c2e5"
      "5aff9565275eb446d8d27066ab4339540aff4d294f74be9b099a3a3c7cd155be",
    component
      "cargo-nightly"
      "73f5400ac6e4a789e4253acfa507bfcff786d4a8c9b41d03cedb32428ea3dc68"
      "3a6193c1897239a1e44f5264f7423db109796c5d5a8e6416e07b39e33b4554f3",
    component
      "rust-std-nightly"
      "b97e4593630291e9666f5da3905e44247eead514951c792b4a606fb08d7f6a3d"
      "e02008ad12b3c834cf6f384dab677f5a747d28e1cd7522ecf0a88485f118eb4e",
    component
      "rustc-dev-nightly"
      "fbc098037c9fa37a0c2c0bda6151734c204c5ec071071395ccbdf797e865b21d"
      "1ee8a9d97024ab6379e0ec8c0bfc20a40d99c5b2b745465dc42b84f44db2f7ac",
    {
      url = "gs://minimal-staging-archives/rust-src-nightly-%{date}.tar.xz",
      sha256 = "3ce6b9d679b5d1840d3ed276e74c8d6b4b1da5ebef2eeb542b588de04ada039f",
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
