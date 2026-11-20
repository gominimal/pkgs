let { subsetOf, Attrs, BuildSpec, Local, Needs, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let detbuild = import "../detbuild/build.ncl" in
let grep = import "../grep/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "27.1.0" in
{
  name = "cargo-mutants",
  # Mutation testing for Rust, built from source with the rust package. It drives
  # whatever `cargo` is on PATH at run time (cargo build / cargo test on mutated
  # copies of the tree) and ships no toolchain of its own, so rust is a test dep
  # here, not a runtime dep: a session that uses it brings its own rust.
  build_deps = [
    { file = "build.sh" } | Local,
    {
      # Mirror of https://github.com/sourcefrog/cargo-mutants/archive/refs/tags/v%{version}.tar.gz
      url = "gs://minimal-staging-archives/sourcefrog/cargo-mutants/v%{version}.tar.gz",
      sha256 = "e57d8c31a8edee7d9265949aef896768729c824626897938e98a5d162a82bda0",
      extract = true,
      strip_prefix = "cargo-mutants-%{version}",
    } | Source,
    base,
    rust,
    toolchain,
    # Deterministic getrandom/getentropy for the offline build (see build.sh).
    detbuild,
  ],

  runtime_deps = [
    glibc,
    subsetOf gcc ["libgcc"],
  ],

  # cargo fetch (see build.sh)
  needs =
    {
      dns = {},
      internet = {},
    } | Needs,

  cmd = "./build.sh",
  build_args = { include version },

  outputs = {
    cargo-mutants = { glob = "usr/bin/cargo-mutants" } | OutputBin,
  },

  tests = {
    version_check =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, grep],
        cmds = [
          ["/bin/bash", "-c", "cargo-mutants mutants --version | grep -qx 'cargo-mutants %{version}'"],
        ],
      } | Test,
    # `cargo mutants --list` on a one-function crate: cargo finds the cargo-mutants
    # subcommand on PATH, cargo-mutants runs `cargo metadata` and lists the mutants of
    # `add`. Nothing is compiled, so no linker is needed.
    list =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, grep, rust],
        cmds = [
          [
            "/bin/bash",
            "-c",
            m%"
              set -euo pipefail
              export CARGO_HOME="$PWD/cargo-home"
              mkdir -p tiny/src
              cd tiny
              printf '[package]\nname = "tiny"\nversion = "0.1.0"\nedition = "2021"\n' > Cargo.toml
              printf 'pub fn add(a: i32, b: i32) -> i32 {\n    a + b\n}\n' > src/lib.rs
              out="$(cargo mutants --list --line-col=false)"
              printf '%s\n' "$out"
              grep -qx 'src/lib.rs: replace add -> i32 with 0' <<<"$out"
              grep -qx 'src/lib.rs: replace + with - in add' <<<"$out"
            "%
          ],
        ],
      } | Test,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "sourcefrog",
        repo = "cargo-mutants",
      },
    } | Attrs,
} | BuildSpec
