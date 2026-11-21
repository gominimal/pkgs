# cargo-llvm-cov: `cargo llvm-cov`, source-based code coverage for Rust
# (-C instrument-coverage). Ships only the cargo subcommand: it brings no
# toolchain and no LLVM. At run time it drives whatever cargo/rustc is on PATH
# and needs llvm-cov + llvm-profdata whose LLVM major matches that rustc. It
# looks for them in `$(rustc --print target-libdir)/../bin` (rustup's
# llvm-tools component), else takes LLVM_COV and LLVM_PROFDATA.
let { subsetOf, Attrs, BuildSpec, Local, Needs, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let grep = import "../grep/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc-runtime = import "../gcc-runtime/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "0.9.2" in
{
  name = "cargo-llvm-cov",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      # The published crate, not the GitHub tag archive: upstream commits no
      # Cargo.lock, and only the .crate carries the lock it was released with.
      url = "https://static.crates.io/crates/cargo-llvm-cov/cargo-llvm-cov-%{version}.crate",
      sha256 = "079b7461474a8fc030a9f7c8b00bdc7fa3e70bd69e408dbab156fdd7899b871e",
      # a .crate is a gzipped tar; build.sh unpacks it (Source extraction keys on the extension)
      extract = false,
    } | Source,
    base,
    rust,
    toolchain,
  ],

  runtime_deps = [
    glibc,
    subsetOf gcc-runtime ["libgcc"],
  ],

  # cargo fetches the crates in the published Cargo.lock (--locked) during the build.
  needs =
    {
      dns = {},
      internet = {},
    } | Needs,

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    cargo-llvm-cov = { glob = "usr/bin/cargo-llvm-cov" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "Apache-2.0 OR MIT",
      source_provenance = {
        category = 'GithubRepo,
        owner = "taiki-e",
        repo = "cargo-llvm-cov",
      },
    } | Attrs,

  tests = {
    version_check =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap, grep],
        cmds = [
          # invoked as cargo invokes a subcommand: argv[1] is the subcommand name
          ["/bin/bash", "-c", "/usr/bin/cargo-llvm-cov llvm-cov --version | grep -qx 'cargo-llvm-cov %{version}'"],
          ["/bin/bash", "-c", "/usr/bin/cargo-llvm-cov llvm-cov --help | grep -q -- '--lcov'"],
        ],
      } | Test,
  },
} | BuildSpec
