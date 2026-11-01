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

let version = "0.2026.10.26.d17fbd0" in
let sha = "d17fbd0c58abf0d5e86825ea64b96aba72b1b31f" in
# Verus's rust-toolchain.toml channel, with rustc-dev (rust_verify links
# rustc_private). The `rust` package ships no rustc-dev, so the toolchain is
# vendored privately even when the versions agree.
let rust = "1.99.1" in
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
  name = "verus-latest",
  # Tracks upstream's newest weekly stable release (tags release/0.YYYY.MM.DD.<sha>).
  # Each release re-pins its Rust toolchain and z3, so a bump re-mirrors the
  # toolchain components, re-vendors the crates and may add a z3-x.y.z package
  # (pkgmgr's toolchain-bundle bump does this; see gominimal/pkgmgr-rs).
  # Verus: SMT-based verification of Rust code annotated with specs and proofs.
  # rust_verify checks the crate, vstd is the verified standard library, z3
  # 4.16.0 is the solver (Verus refuses any other version).
  # Single-file `verus` uses the vstd built here and needs no network.
  # `cargo verus` projects depend on vstd from crates.io (upstream's design: the
  # release's toolchain manifest names a registry vstd), so the first
  # `cargo verus verify` fetches vstd, its five verus_* siblings and their deps.
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/verus-lang/verus/archive/refs/tags/release/%{version}.tar.gz",
      sha256 = "f0b0985dc8b7b1daa150acfe86034ef76a3ad31ae6afaf500fe2bcf7478c473e",
      extract = true,
      strip_prefix = "verus-release-%{version}",
    } | Source,
    # `cargo vendor --locked --versioned-dirs` of source/ (372 crates incl. the
    # utaal/getopts git fork). Packed deterministically: sorted, mtime 0,
    # root:root, gzip -n.
    {
      url = "gs://minimal-staging-archives/verus-vendor-%{version}.tar.gz",
      sha256 = "5e3f794a840e95f3fce62bdb36eb1d355e22bd53eb818f220aa6ecbb957356ba",
      extract = false,
    } | Source,
    component
      "rustc"
      "2ff05ff9c08a90861e7f6e4065b40a8b87463b4576186fd613871c3e37f2091f"
      "acdcdfe09ae1f103aa9a2b7f88903a9588bc2e99288af10e6fbf5514e2e49f25",
    component
      "cargo"
      "53f3521949404d595efb06a55c12c5658d4ed1c75566f33d3d514eaebe70bd8a"
      "5156832e0c1254e9b49a79edabdc6d4c35f32f8fc1cf3ca700f268ff96087ab0",
    component
      "rust-std"
      "109b074225bf5b9ea3820890876bfdf4ed161adbfaf94b2b4b5984c85ee5d958"
      "e25668477083d6a9ddb87b9beb9c00742225f38233ccb4bfba3afa7a07427f52",
    component
      "rustc-dev"
      "e2b1c9ffe50910d5274339b52774eec05433682835219566449cd09c67c1d1d2"
      "eb786738654b9f640816aec1e9bf8fed5fc5dd0137ca1a6cec494965ec08a758",
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
    # `cargo verus new` runs `git init` and aborts if it fails.
    git,
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
          # cargo-verus knows its own release (build.sh step 3): `new` resolves
          # the vstd dependency from the compiled-in toolchain manifest.
          ["/bin/bash", "-c", "cd /tmp && cargo-verus verus new --bin p >/tmp/new.out 2>&1 && grep -qE '^vstd = \"=0\\.0\\.0-[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{4}\"$' p/Cargo.toml && test -f p/src/main.rs"],
        ],
      } | Test,
  },
} | BuildSpec
