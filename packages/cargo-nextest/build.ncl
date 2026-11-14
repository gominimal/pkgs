let { subsetOf, Attrs, BuildSpec, Local, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let bash-bootstrap = import "../bash-bootstrap/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "0.9.152" in
{
  name = "cargo-nextest",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/nextest-rs/nextest/archive/refs/tags/cargo-nextest-%{version}.tar.gz",
      sha256 = "b93dfdf2c5d187f0154e71ee86bcfc40e8ea39abfe7bf20f95f1fa05c12afb2f",
      extract = true,
      strip_prefix = "nextest-cargo-nextest-%{version}",
    } | Source,
    base,
    rust,
    toolchain,
  ],

  runtime_deps = [
    glibc,
    subsetOf gcc ["libgcc"],
  ],

  needs = {
    dns = {},
    internet = {},
  },

  cmd = "./build.sh",
  build_args = {
    include version,
  },

  outputs = {
    cargo-nextest = { glob = "usr/bin/cargo-nextest" } | OutputBin,
  },

  attrs =
    {
      upstream_version = version,
      license_spdx = "MIT OR Apache-2.0",
      source_provenance = {
        category = 'GithubRepo,
        owner = "nextest-rs",
        repo = "nextest",
      },
      build_cost_multiple = 2,
    } | Attrs,

  tests = {
    smoke =
      {
        class = 'Standalone,
        test_deps = [bash-bootstrap],
        cmds = [
          ["/bin/bash", "-c", "cargo-nextest nextest --version"],
          ["/bin/bash", "-c", "cargo-nextest nextest --help"],
        ],
      } | Test,
  },
} | BuildSpec
