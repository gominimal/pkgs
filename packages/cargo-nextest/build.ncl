let { subsetOf, Attrs, BuildSpec, Local, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "0.9.151" in
{
  name = "cargo-nextest",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/nextest-rs/nextest/archive/refs/tags/cargo-nextest-%{version}.tar.gz",
      sha256 = "613c8855e6a5b9f9d12920bf74a0c191af3f8b5f86ff4cf27446f0f7adfc44ec",
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
        test_deps = [base],
        cmds = [
          ["/bin/bash", "-c", "cargo-nextest nextest --version"],
          ["/bin/bash", "-c", "cargo-nextest nextest --help"],
        ],
      } | Test,
  },
} | BuildSpec
