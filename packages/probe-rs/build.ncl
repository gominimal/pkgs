let { standaloneTest, subsetOf, BuildSpec, Local, Needs, OutputBin, Source, .. } = import "minimal.ncl" in
let base = import "../base/build.ncl" in
let gcc = import "../gcc/build.ncl" in
let glibc = import "../glibc/build.ncl" in
let rust = import "../rust/build.ncl" in
let toolchain = import "../toolchain/build.ncl" in

let version = "0.31.0" in
{
  name = "probe-rs",

  build_deps = [
    { file = "build.sh" } | Local,
    {
      url = "https://github.com/probe-rs/probe-rs/archive/refs/tags/v%{version}.tar.gz",
      sha256 = "7a5022d6956daaa8dba96bb3aedf2ace0b5a76a60729d93971c9dab439ac045e",
      extract = true,
      strip_prefix = "probe-rs-%{version}",
    } | Source,
    base,
    rust,
    toolchain,
  ],

  runtime_deps = [
    glibc,
    subsetOf gcc ["libgcc"],
  ],

  needs =
    {
      dns = {},
      internet = {},
    } | Needs,

  cmd = "./build.sh",

  outputs = {
    cargo-embed = { glob = "usr/bin/cargo-embed" } | OutputBin,
    cargo-flash = { glob = "usr/bin/cargo-flash" } | OutputBin,
    probe-rs = { glob = "usr/bin/probe-rs" } | OutputBin,
  },

  tests = {
    smoketest = standaloneTest "/bin/probe-rs --version",
  },

  attrs = {
    upstream_version = version,
    license_spdx = "Apache-2.0",
    source_provenance = {
      category = 'GithubRepo,
      owner = "probe-rs",
      repo = "probe-rs",
    },
  },
} | BuildSpec
