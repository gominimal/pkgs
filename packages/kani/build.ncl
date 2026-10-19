let { subsetOf, Attrs, BuildSpec, Local, OutputBin, OutputData, Source, Test, .. } =
  import "minimal.ncl"
in
let { target, .. } = import "config.ncl" in
let base = import "../base/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let zlib = import "../zlib/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let binutils = import "../binutils/build.ncl" in
let cbmc = import "../cbmc/build.ncl" in
let kissat = import "../kissat/build.ncl" in

let version = "0.68.0" in
# kani-0.68.0's rust-toolchain.toml. Kani links rustc_private, so the nightly
# must match exactly; bump it together with `version`.
let nightly = "2026-08-21" in

# The official nightly component tarballs, mirrored to gs:// as for
# rust-nightly-charon (same files as static.rust-lang.org/dist/<date>/, verified
# against its .sha256 files before upload).
let component = fun base_name amd64_sha arm64_sha =>
  (match {
    { arch = 'Amd64, .. } =>
      {
        url = "gs://minimal-staging-archives/%{base_name}-%{nightly}-x86_64-unknown-linux-gnu.tar.xz",
        sha256 = amd64_sha,
        extract = false,
      } | Source,
    { arch = 'Arm64, .. } =>
      {
        url = "gs://minimal-staging-archives/%{base_name}-%{nightly}-aarch64-unknown-linux-gnu.tar.xz",
        sha256 = arm64_sha,
        extract = false,
      } | Source,
  }
  ) target
in
{
  name = "kani",
  # Kani, AWS's bounded model checker for Rust: `cargo kani` compiles a crate
  # with kani-compiler (a rustc driver) to CBMC's goto format and checks its
  # #[kani::proof] harnesses with CBMC + kissat.
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/model-checking/kani/archive/refs/tags/kani-%{version}.tar.gz",
      sha256 = "f00e032df55d1dee6aff7f9ae6b9e7f9af665b60e135892a2a210a0376492810",
      extract = true,
      strip_prefix = "kani-kani-%{version}",
    } | Source,
    # `cargo vendor --locked --versioned-dirs` of the kani workspace, synced with the toolchain's
    # rust-src library/Cargo.toml so `-Z build-std` resolves offline too (311
    # crates, incl. the Nadrieril/tracing-tree git fork), plus the `charon`
    # submodule at kani's pin (b250680a), which the GitHub archive omits and
    # cargo needs to resolve the workspace (kani-compiler's optional `llbc`
    # feature). Packed deterministically: sorted, mtime 0, root:root, gzip -n.
    {
      url = "gs://minimal-staging-archives/kani-deps-%{version}.tar.gz",
      sha256 = "64837def2ba4ba52b23a4438df26200a58a21ecefe6a6698cc9ea6599ae467ef",
      extract = false,
    } | Source,
    component
      "rustc-nightly"
      "e531815fa551362b5a485e0d286b6c96555312d49359c0b8fe9e8f34c45594b4"
      "1752c051596e4d63575f3c50939f76b680bebb412c249593d0f3231ea962bee4",
    component
      "cargo-nightly"
      "51306dcd70ad7ea807727fb313b6a0cbc6406934ad230b6c18db79a97c539c57"
      "6f116a4062e6f0fc478da3f9728b2a48da1a6eb3589aa1315042d6197c3a36e0",
    component
      "rust-std-nightly"
      "52cd12570c6f967c3d04173e061fdab1cd44ab9613f53df8e04f7ce3b52ea3a3"
      "84ed3496bc95b017762d4c09a5c85f21f2cce62a27d963fb403d6beacfb4ad59",
    component
      "rustc-dev-nightly"
      "175a1fb7447dc3c4407d6ea568eeb5cbe15316c8e2e4ee06a93864a466f71bdb"
      "38306a72cd3cfdea0722dcca7e4a70ba077721c3a230550d5a722af7ba2271d5",
    # rustfmt: `--concrete-playback=inplace` formats the test it writes back.
    component
      "rustfmt-nightly"
      "82a6352f147a405508247643984927c14582bbc7d7349a460bdb747ffe5add21"
      "682f619eae2e9c2bb4673de8883d93595027f34bb3829648b5c979566dc3fec9",
    {
      url = "gs://minimal-staging-archives/rust-src-nightly-%{nightly}.tar.xz",
      sha256 = "b72d49563c50bf06ef9aa0dcbf57941051547e874b8ce6788aad92f67942f8cd",
      extract = false,
    } | Source,
    base,
    toolchain,
    # The bundler copies these from PATH; build.sh swaps the copies for links.
    cbmc,
    kissat,
  ],

  runtime_deps = [
    base, # /bin/sh for the kani / cargo-kani wrappers
    glibc,
    zlib,
    subsetOf gcc ["libgcc", "libstdcpp"],
    # Kani runs CBMC and kissat by name (bundle bin/ links to them).
    cbmc,
    kissat,
    # `cargo kani` links build scripts and proc-macros of the crate under test;
    # the wrappers point cargo's linker at gcc.
    gcc,
    binutils,
  ],

  cmd = "./build.sh",
  build_args = {
    include version,
    include nightly,
  },

  outputs = {
    kani = { glob = "usr/bin/kani" } | OutputBin,
    cargo-kani = { glob = "usr/bin/cargo-kani" } | OutputBin,
    tree = { glob = "usr/lib/kani/**", allow_executable = true } | OutputData,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "Apache-2.0 OR MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "model-checking",
        repo = "kani",
      },
    } | Attrs,

  tests = {
    smoke =
      {
        class = 'Standalone,
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "kani --version | grep -q '%{version}'"],
          # A harness Kani must refute: u8 addition overflows.
          ["/bin/bash", "-c", "printf '#[kani::proof]\\nfn h(){ let a: u8 = kani::any(); let b: u8 = kani::any(); let _ = a + b; }\\n' > /tmp/bad.rs; kani /tmp/bad.rs >/tmp/bad.out 2>&1; test $? -ne 0 && grep -q 'VERIFICATION:- FAILED' /tmp/bad.out"],
          # And one it must prove.
          ["/bin/bash", "-c", "printf '#[kani::proof]\\nfn h(){ let a: u8 = kani::any(); let b: u8 = kani::any(); let _ = a.wrapping_add(b); }\\n' > /tmp/ok.rs; kani /tmp/ok.rs >/tmp/ok.out 2>&1 && grep -q 'VERIFICATION:- SUCCESSFUL' /tmp/ok.out"],
        ],
      } | Test,
  },
} | BuildSpec
