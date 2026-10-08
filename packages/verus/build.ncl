let { subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } =
  import "minimal.ncl"
in
let { target, .. } = import "config.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let git = import "../git/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let zlib = import "../zlib/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let binutils = import "../binutils/build.ncl" in
let z3-4-16-0 = import "../z3-4.16.0/build.ncl" in

let version = "0.2026.10.04.426d8b0" in
let sha = "426d8b01e7ffb910a36c15e1f870ff985bb61eef" in
# Verus's rust-toolchain.toml: stable 1.98.1 with rustc-dev (rust_verify links
# rustc_private). The `rust` package is also 1.98.1 but ships no rustc-dev.
let rust = "1.98.1" in
let z3 = "4.16.0" in

# The official stable component tarballs, mirrored to gs:// (verified against
# static.rust-lang.org's .sha256 files before upload).
let component = fun base_name amd64_sha arm64_sha =>
  (match {
    { arch = 'Amd64, .. } =>
      {
        url = "gs://minimal-staging-archives/%{base_name}-%{rust}-x86_64-unknown-linux-gnu.tar.xz",
        sha256 = amd64_sha,
        extract = false,
      } | Source,
    { arch = 'Arm64, .. } =>
      {
        url = "gs://minimal-staging-archives/%{base_name}-%{rust}-aarch64-unknown-linux-gnu.tar.xz",
        sha256 = arm64_sha,
        extract = false,
      } | Source,
  }
  ) target
in
{
  name = "verus",
  # Verus: SMT-based verification of Rust code annotated with specs and proofs.
  # rust_verify checks the crate, vstd is the verified standard library, z3
  # 4.16.0 is the solver (Verus refuses any other version).
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/verus-lang/verus/archive/refs/tags/release/%{version}.tar.gz",
      sha256 = "55dc63445ae2c583534cb8cc04e7834876b6dd9d4456c196c726336acb98d773",
      extract = true,
      strip_prefix = "verus-release-%{version}",
    } | Source,
    # `cargo vendor --locked --versioned-dirs` of source/ (372 crates incl. the
    # utaal/getopts git fork). Packed deterministically: sorted, mtime 0,
    # root:root, gzip -n.
    {
      url = "gs://minimal-staging-archives/verus-vendor-%{version}.tar.gz",
      sha256 = "81b2adb5690b10067d01e22c5178ae55a5bd9cbf3696c81bb9adb014dec1d54e",
      extract = false,
    } | Source,
    component
      "rustc"
      "e974f036b28565f37c0f3bd92ddefa809bee16c04f9dcf07b9ed96e05aaaf7c4"
      "89fb83041993b48816514815606f53a5264729b8b449671a6b291e6f0ae74f40",
    component
      "cargo"
      "ea1de9f9e23107d97ee2b41a72c552f34064a593da503789218387aee59f3ba4"
      "c09425a7f300af148c0bdfded0e7d5f1fe7c075b2b9674e8935afa769297b2f6",
    component
      "rust-std"
      "fa3ff450172a16c026944030230c5069947af93c728d9179971d44e5e0cfb561"
      "9bf796a6ec5b004813ebd0b650775a7c6a4f3aae97ad362ae294798dca4f3b23",
    component
      "rustc-dev"
      "97c49fd126d47aa0446488e2674af8b3062b1ec8d72d59ce83d43e45f34a5245"
      "840dc948f997cc3eca0bcd925ac5a921f9d8d702a17fd8f3a1f342d1a95bdacc",
    base,
    toolchain,
    # Verus's build scripts read version info from git (see build.sh).
    git,
    # vstd is verified during the build.
    z3-4-16-0,
  ],

  runtime_deps = [
    base, # /bin/sh for the verus / cargo-verus wrappers
    glibc,
    zlib,
    subsetOf gcc ["libgcc", "libstdcpp"],
    z3-4-16-0,
    # `verus --compile` and `cargo verus` link through the toolchain; the
    # wrappers point the linker at gcc.
    gcc,
    binutils,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
    include sha,
    include rust,
    include z3,
  },

  outputs = {
    verus = { glob = "usr/bin/verus" } | OutputBin,
    cargo-verus = { glob = "usr/bin/cargo-verus" } | OutputBin,
    tree = { glob = "usr/lib/verus/**", allow_executable = true } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "verus-lang",
        repo = "verus",
      },
    } | Attrs,

  tests = {
    smoke =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          # A postcondition Verus must reject...
          ["/bin/bash", "-c", "printf 'use vstd::prelude::*;\\nverus!{\\nfn inc(x: u8) -> (r: u8) requires x < 255 ensures r == x { x + 1 }\\nfn main(){}\\n}\\n' > /tmp/bad.rs; verus /tmp/bad.rs >/tmp/bad.out 2>&1; test $? -ne 0 && grep -q 'postcondition not satisfied' /tmp/bad.out"],
          # ...and the corrected one it must prove.
          ["/bin/bash", "-c", "printf 'use vstd::prelude::*;\\nverus!{\\nfn inc(x: u8) -> (r: u8) requires x < 255 ensures r == x + 1 { x + 1 }\\nfn main(){}\\n}\\n' > /tmp/ok.rs; verus /tmp/ok.rs >/tmp/ok.out 2>&1 && grep -qE '[1-9][0-9]* verified, 0 errors' /tmp/ok.out"],
        ],
      } | Test,
  },
} | BuildSpec
