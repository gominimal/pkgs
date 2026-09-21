let { subsetOf, Attrs, BuildSpec, Local, OutputBin, Source, Test, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in

let version = "0.9.145" in
{
  name = "cargo-nextest",
  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/nextest-rs/nextest/archive/refs/tags/cargo-nextest-%{version}.tar.gz",
      sha256 = "6ba31b7dace0cfa57a7f9f534a82732d037481e161e076bd713c3edf1fdf6a63",
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
